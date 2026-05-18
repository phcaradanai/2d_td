import { useCallback, useEffect, useState } from 'react';
import { api, type AccessProfile, normalizeProfiles } from '../api/client';
import { useToast } from '../context/ToastContext';
import Modal from '../components/Modal';

const defaultConfig = JSON.stringify({
  mode: 'demo',
  enabled_levels: [1],
  max_wave: 60,
  allow_leaderboard_submit: false,
  allow_save_resume: true,
  allow_sandbox: false,
  allow_challenge_mode: false,
}, null, 2);

export default function AccessProfilesPage() {
  const { toast } = useToast();
  const [profiles, setProfiles] = useState<AccessProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);
  const [editItem, setEditItem] = useState<AccessProfile | null>(null);

  // Create form
  const [newKey, setNewKey] = useState('');
  const [newName, setNewName] = useState('');
  const [newConfig, setNewConfig] = useState(defaultConfig);
  const [jsonError, setJsonError] = useState('');

  const fetchProfiles = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get<{ items: Record<string, unknown>[] }>('/api/admin/access-profiles');
      setProfiles(normalizeProfiles(data.items || []));
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => { fetchProfiles(); }, [fetchProfiles]);

  const validateJson = (json: string): boolean => {
    try {
      JSON.parse(json);
      setJsonError('');
      return true;
    } catch {
      setJsonError('Invalid JSON');
      return false;
    }
  };

  const handleCreate = async () => {
    if (!newKey.trim() || !newName.trim()) {
      toast('profile_key and name are required', 'err');
      return;
    }
    if (!validateJson(newConfig)) {
      toast('Fix JSON errors before saving', 'err');
      return;
    }
    try {
      await api.post('/api/admin/access-profiles', {
        profile_key: newKey.trim().toLowerCase(),
        name: newName.trim(),
        config_json: JSON.parse(newConfig),
      });
      toast('Profile created', 'ok');
      setCreateOpen(false);
      setNewKey('');
      setNewName('');
      setNewConfig(defaultConfig);
      fetchProfiles();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const handleUpdate = async () => {
    if (!editItem) return;
    if (!validateJson(newConfig)) {
      toast('Fix JSON errors before saving', 'err');
      return;
    }
    try {
      const key = editItem.profile_key ?? (editItem as unknown as Record<string, unknown>).ProfileKey as string ?? '';
      await api.patch(`/api/admin/access-profiles/${key}`, {
        name: newName,
        config_json: JSON.parse(newConfig),
        is_active: true,
      });
      toast('Profile updated', 'ok');
      setEditItem(null);
      fetchProfiles();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const toggleActive = async (profile: AccessProfile) => {
    try {
      const config = JSON.parse(profile.config_json ?? '{}');
      await api.patch(`/api/admin/access-profiles/${profile.profile_key}`, {
        name: profile.name,
        config_json: config,
        is_active: !profile.is_active,
      });
      toast(profile.is_active ? 'Profile disabled' : 'Profile enabled', 'ok');
      fetchProfiles();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const openEdit = (p: AccessProfile) => {
    setEditItem(p);
    setNewName(p.name ?? '');
    const raw = p.config_json ?? '{}';
    try {
      setNewConfig(JSON.stringify(JSON.parse(raw), null, 2));
    } catch {
      setNewConfig(raw || '{}');
    }
  };
  const closeEdit = () => {
    setEditItem(null);
    setJsonError('');
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Access Profiles</h1>
          <p>{profiles.length} profiles</p>
        </div>
        <button className="btn-ok" onClick={() => {
          setCreateOpen(true);
          setNewKey('');
          setNewName('');
          setNewConfig(defaultConfig);
          setJsonError('');
        }}>Create Profile</button>
      </div>

      {loading ? (
        <div className="loading">Loading profiles...</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Profile Key</th>
                <th>Name</th>
                <th>Config</th>
                <th>Status</th>
                <th>Updated</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {profiles.length === 0 && (
                <tr><td colSpan={6} className="empty-state">No profiles</td></tr>
              )}
              {profiles.map(p => (
                <tr key={p.profile_key}>
                  <td className="mono">{p.profile_key}</td>
                  <td>{p.name}</td>
                  <td>
                    <pre style={{ background: 'var(--bg0)', padding: '2px 6px', fontSize: 10, maxHeight: 60, overflow: 'auto', margin: 0 }}>
                      {(() => { try { return JSON.stringify(JSON.parse(p.config_json), null, 2); } catch { return p.config_json; } })()}
                    </pre>
                  </td>
                  <td>
                    <span className={`badge ${p.is_active ? 'badge-active' : 'badge-inactive'}`}>
                      {p.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td style={{ fontSize: 11 }}>{new Date(p.updated_at).toLocaleDateString()}</td>
                  <td>
                    <div className="actions-cell">
                      <button className="btn-sm" onClick={() => openEdit(p)}>Edit</button>
                      <button className={`btn-sm ${p.is_active ? 'btn-danger' : 'btn-ok'}`} onClick={() => toggleActive(p)}>
                        {p.is_active ? 'Disable' : 'Enable'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Create modal */}
      <Modal open={createOpen} onClose={() => setCreateOpen(false)} title="Create Access Profile">
        <div className="form-group">
          <label>Profile Key</label>
          <input value={newKey} onChange={(e) => setNewKey(e.target.value)} placeholder="e.g. my_custom_profile" autoFocus />
        </div>
        <div className="form-group">
          <label>Name</label>
          <input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="Human-readable name" />
        </div>
        <div className="form-group json-editor">
          <label>Config JSON</label>
          <textarea
            className={jsonError ? 'invalid' : ''}
            value={newConfig ?? ''}
            onChange={(e) => { setNewConfig(e.target.value); validateJson(e.target.value); }}
            rows={12}
          />
          {jsonError && <div className="json-error">{jsonError}</div>}
          {!jsonError && (newConfig ?? '').length > 0 && <div className="json-ok">Valid JSON</div>}
        </div>
        <div className="form-actions">
          <button className="btn-ok" onClick={handleCreate}>Create Profile</button>
          <button onClick={() => setCreateOpen(false)}>Cancel</button>
        </div>
      </Modal>

      {/* Edit modal */}
      <Modal open={!!editItem} onClose={closeEdit} title={`Edit: ${editItem?.profile_key ?? (editItem as unknown as Record<string, unknown>)?.ProfileKey ?? ''}`}>
        <div className="form-group">
          <label>Name</label>
          <input value={newName} onChange={(e) => setNewName(e.target.value)} />
        </div>
        <div className="form-group json-editor">
          <label>Config JSON</label>
          <textarea
            className={jsonError ? 'invalid' : ''}
            value={newConfig ?? ''}
            onChange={(e) => { setNewConfig(e.target.value); validateJson(e.target.value); }}
            rows={12}
          />
          {jsonError && <div className="json-error">{jsonError}</div>}
          {!jsonError && (newConfig ?? '').length > 0 && <div className="json-ok">Valid JSON</div>}
        </div>
        <div className="form-actions">
          <button className="btn-ok" onClick={handleUpdate}>Save Changes</button>
          <button onClick={closeEdit}>Cancel</button>
        </div>
      </Modal>
    </div>
  );
}
