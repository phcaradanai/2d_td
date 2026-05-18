import { useCallback, useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api, type RuntimeInstance, type ResolvedAccess, type AccessOverride, type AccessProfile } from '../api/client';
import { useToast } from '../context/ToastContext';

interface InstallDetail {
  ok: boolean;
  install_id: string;
  latest: RuntimeInstance;
  sessions: RuntimeInstance[];
  tags: string[];
  overrides: AccessOverride[];
  resolved: ResolvedAccess | null;
}

interface AccessEditor {
  mode: string;
  enabled_levels: string;
  max_wave: number;
  allow_leaderboard_submit: boolean;
  allow_save_resume: boolean;
  allow_sandbox: boolean;
  allow_challenge_mode: boolean;
  starts_at: string;
  ends_at: string;
}

const defaultEditor: AccessEditor = {
  mode: 'full',
  enabled_levels: 'all',
  max_wave: 60,
  allow_leaderboard_submit: true,
  allow_save_resume: true,
  allow_sandbox: true,
  allow_challenge_mode: true,
  starts_at: '',
  ends_at: '',
};

export default function InstallDetailPage() {
  const { installId } = useParams<{ installId: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [data, setData] = useState<InstallDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [editor, setEditor] = useState<AccessEditor>(defaultEditor);
  const [profiles, setProfiles] = useState<AccessProfile[]>([]);
  const [tagInput, setTagInput] = useState('');

  const fetchData = useCallback(async () => {
    if (!installId) return;
    setLoading(true);
    try {
      const [detail, profileData] = await Promise.all([
        api.get<InstallDetail>(`/api/admin/installs/${installId}`),
        api.get<{ items: AccessProfile[] }>('/api/admin/access-profiles'),
      ]);
      setData(detail);
      setProfiles(profileData.items || []);
      if (detail.resolved?.config) {
        const c = detail.resolved.config;
        setEditor({
          mode: c.mode || 'demo',
          enabled_levels: Array.isArray(c.enabled_levels) ? c.enabled_levels.join(',') : String(c.enabled_levels ?? 'all'),
          max_wave: c.max_wave ?? 60,
          allow_leaderboard_submit: c.allow_leaderboard_submit ?? false,
          allow_save_resume: c.allow_save_resume ?? false,
          allow_sandbox: c.allow_sandbox ?? false,
          allow_challenge_mode: c.allow_challenge_mode ?? false,
          starts_at: '',
          ends_at: '',
        });
      }
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    } finally {
      setLoading(false);
    }
  }, [installId, toast]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const applyProfile = async (targetType: string, targetValue: string, profileKey: string) => {
    const endpoint = targetType === 'install_id'
      ? `/api/admin/installations/${targetValue}/access`
      : `/api/admin/runtimes/${targetValue}/access`;
    try {
      await api.patch(endpoint, { profile_key: profileKey });
      toast('Profile applied', 'ok');
      fetchData();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const saveCustomOverride = async (targetType: string, targetValue: string) => {
    const levels = editor.enabled_levels === 'all' ? 'all' : editor.enabled_levels.split(',').map(s => parseInt(s.trim(), 10)).filter(n => !isNaN(n));
    const overrideJson = {
      mode: editor.mode,
      enabled_levels: levels,
      max_wave: editor.max_wave,
      allow_leaderboard_submit: editor.allow_leaderboard_submit,
      allow_save_resume: editor.allow_save_resume,
      allow_sandbox: editor.allow_sandbox,
      allow_challenge_mode: editor.allow_challenge_mode,
    };
    const endpoint = targetType === 'install_id'
      ? `/api/admin/installations/${targetValue}/access`
      : `/api/admin/runtimes/${targetValue}/access`;
    try {
      await api.patch(endpoint, { override_json: overrideJson, priority: 10 });
      toast('Custom override saved', 'ok');
      fetchData();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const disableOverride = async (id: number) => {
    try {
      await api.patch(`/api/admin/overrides/${id}`, { is_active: false });
      toast('Override disabled', 'ok');
      fetchData();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const addTag = async () => {
    if (!tagInput.trim() || !installId) return;
    try {
      await api.post('/api/admin/tags', { target_type: 'install_id', target_value: installId, tag: tagInput.trim().toLowerCase() });
      toast('Tag added', 'ok');
      setTagInput('');
      fetchData();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const removeTag = async (tag: string) => {
    if (!installId) return;
    try {
      await api.delete('/api/admin/tags', { target_type: 'install_id', target_value: installId, tag });
      toast('Tag removed', 'ok');
      fetchData();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  if (loading) return <div className="loading">Loading install detail...</div>;
  if (!data) return <div className="err-msg">Install not found</div>;

  const { latest, sessions, tags, overrides, resolved } = data;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Install Detail</h1>
          <p className="mono">{installId}</p>
        </div>
        <button onClick={() => navigate('/runtimes')}>Back to Runtimes</button>
      </div>

      {/* Key info */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title">Identity</div>
        <div className="kv-grid">
          <div className="k">Install ID</div><div className="v mono">{installId}</div>
          <div className="k">Latest Runtime</div><div className="v mono">{latest.runtime_id}</div>
          <div className="k">Player ID</div><div className="v mono">{latest.player_id || '—'}</div>
          <div className="k">Build ID</div><div className="v">{latest.build_id}</div>
          <div className="k">Platform</div><div className="v">{latest.platform}</div>
          <div className="k">Game Version</div><div className="v">{latest.game_version || '—'}</div>
          <div className="k">Last Seen</div><div className="v">{new Date(latest.last_seen_at).toLocaleString()}</div>
          <div className="k">Created</div><div className="v">{new Date(latest.created_at).toLocaleString()}</div>
          <div className="k">Tags</div>
          <div className="v">
            {tags.length === 0 && <span style={{ color: 'var(--ink4)' }}>No tags</span>}
            {tags.map(t => (
              <span key={t} className="tag-chip">{t}<span className="rm" onClick={() => removeTag(t)}>&times;</span></span>
            ))}
            <span style={{ display: 'inline-flex', gap: 4, marginLeft: 6 }}>
              <input
                placeholder="Add tag..."
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') addTag(); }}
                style={{ background: 'var(--bg2)', border: '1px solid var(--line2)', color: 'var(--ink1)', padding: '1px 6px', fontFamily: 'inherit', fontSize: 11, width: 80 }}
              />
              <button className="btn-sm btn-ok" onClick={addTag}>+</button>
            </span>
          </div>
        </div>
      </div>

      {/* Resolved access */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title">Resolved Access</div>
        {resolved ? (
          <div className="kv-grid">
            <div className="k">Mode</div><div className="v"><span className={`badge badge-${resolved.config.mode}`}>{resolved.config.mode}</span></div>
            <div className="k">Levels</div><div className="v">{Array.isArray(resolved.config.enabled_levels) ? resolved.config.enabled_levels.join(', ') : String(resolved.config.enabled_levels)}</div>
            <div className="k">Max Wave</div><div className="v">{resolved.config.max_wave}</div>
            <div className="k">Leaderboard</div><div className="v">{resolved.config.allow_leaderboard_submit ? 'Yes' : 'No'}</div>
            <div className="k">Save/Resume</div><div className="v">{resolved.config.allow_save_resume ? 'Yes' : 'No'}</div>
            <div className="k">Sandbox</div><div className="v">{resolved.config.allow_sandbox ? 'Yes' : 'No'}</div>
            <div className="k">Challenge Mode</div><div className="v">{resolved.config.allow_challenge_mode ? 'Yes' : 'No'}</div>
            <div className="k">Resolved From</div><div className="v"><span className="badge badge-custom">{resolved.resolved_from}</span></div>
            <div className="k">Profile Key</div><div className="v mono">{resolved.profile_key || '—'}</div>
          </div>
        ) : (
          <div className="empty-state">No resolved access data</div>
        )}
      </div>

      {/* Quick profile apply */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title">Quick Apply Profile</div>
        <p className="warn-note">Recommended: apply to install_id. Runtime_id overrides are temporary/debug only.</p>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
          {profiles.filter(p => p.is_active).map(p => (
            <button key={p.profile_key} className="btn-sm btn-ok" onClick={() => applyProfile('install_id', installId!, p.profile_key)}>
              {p.profile_key}
            </button>
          ))}
        </div>
        <div style={{ color: 'var(--ink3)', fontSize: 10, marginBottom: 6 }}>Debug: apply to runtime_id</div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {profiles.filter(p => p.is_active).map(p => (
            <button key={p.profile_key} className="btn-sm" onClick={() => applyProfile('runtime_id', latest.runtime_id, p.profile_key)}>
              {p.profile_key} (runtime)
            </button>
          ))}
        </div>
      </div>

      {/* Custom access editor */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title">Custom Access Editor</div>
        <div className="form-row">
          <div className="form-group">
            <label>Mode</label>
            <select value={editor.mode} onChange={(e) => setEditor({ ...editor, mode: e.target.value })}>
              <option value="demo">Demo</option>
              <option value="full">Full</option>
              <option value="custom">Custom</option>
            </select>
          </div>
          <div className="form-group">
            <label>Enabled Levels (comma-separated or "all")</label>
            <input value={editor.enabled_levels} onChange={(e) => setEditor({ ...editor, enabled_levels: e.target.value })} />
          </div>
          <div className="form-group">
            <label>Max Wave</label>
            <input type="number" value={editor.max_wave} onChange={(e) => setEditor({ ...editor, max_wave: parseInt(e.target.value) || 60 })} />
          </div>
        </div>
        <div className="checkbox-group" style={{ marginBottom: 12 }}>
          <label><input type="checkbox" checked={editor.allow_leaderboard_submit} onChange={(e) => setEditor({ ...editor, allow_leaderboard_submit: e.target.checked })} /> Leaderboard</label>
          <label><input type="checkbox" checked={editor.allow_save_resume} onChange={(e) => setEditor({ ...editor, allow_save_resume: e.target.checked })} /> Save/Resume</label>
          <label><input type="checkbox" checked={editor.allow_sandbox} onChange={(e) => setEditor({ ...editor, allow_sandbox: e.target.checked })} /> Sandbox</label>
          <label><input type="checkbox" checked={editor.allow_challenge_mode} onChange={(e) => setEditor({ ...editor, allow_challenge_mode: e.target.checked })} /> Challenge Mode</label>
        </div>
        <div className="form-actions">
          <button className="btn-ok" onClick={() => saveCustomOverride('install_id', installId!)}>Save to Install</button>
          <button onClick={() => saveCustomOverride('runtime_id', latest.runtime_id)}>Save to Runtime (debug)</button>
        </div>
      </div>

      {/* Active overrides */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title">Active Overrides</div>
        {overrides.length === 0 && <div className="empty-state">No active overrides</div>}
        {overrides.map(o => (
          <div key={o.id} style={{ marginBottom: 8, padding: '8px 0', borderBottom: '1px solid var(--line)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <span className="badge badge-custom" style={{ marginRight: 8 }}>{o.target_type}: {o.target_value}</span>
                <span className="mono" style={{ fontSize: 11 }}>profile: {o.profile_key || 'custom json'}</span>
                <span style={{ color: 'var(--ink3)', fontSize: 10, marginLeft: 8 }}>priority {o.priority}</span>
              </div>
              <button className="btn-sm btn-danger" onClick={() => disableOverride(o.id)}>Disable</button>
            </div>
            {o.override_json && (
              <pre style={{ background: 'var(--bg0)', padding: 6, fontSize: 11, overflow: 'auto', maxHeight: 100, marginTop: 4 }}>
                {JSON.stringify(JSON.parse(o.override_json), null, 2)}
              </pre>
            )}
          </div>
        ))}
      </div>

      {/* Sessions */}
      <div className="card">
        <div className="card-title">Runtime Sessions ({sessions.length})</div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Runtime ID</th>
                <th>Build</th>
                <th>Platform</th>
                <th>Mode</th>
                <th>Last Seen</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map(s => (
                <tr key={s.runtime_id}>
                  <td className="mono">{s.runtime_id}</td>
                  <td>{s.build_id}</td>
                  <td>{s.platform}</td>
                  <td>{s.access_mode ? <span className={`badge badge-${s.access_mode}`}>{s.access_mode}</span> : '—'}</td>
                  <td>{new Date(s.last_seen_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
