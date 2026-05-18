import { useCallback, useEffect, useState } from 'react';
import { api, type AccessToken, type AccessProfile, type TokenRedemption } from '../api/client';
import { useToast } from '../context/ToastContext';
import Modal from '../components/Modal';

interface TokenForm {
  name: string;
  description: string;
  prefix: string;
  count: number;
  profile_key: string;
  override_json: string;
  grant_target_type: string;
  max_redemptions: number;
  per_install_limit: number;
  grant_duration_hours: string;
  starts_at: string;
  expires_at: string;
  is_active: boolean;
}

const defaultForm: TokenForm = {
  name: '',
  description: '',
  prefix: 'TKN',
  count: 1,
  profile_key: '',
  override_json: '',
  grant_target_type: 'install_id',
  max_redemptions: 1,
  per_install_limit: 1,
  grant_duration_hours: '',
  starts_at: '',
  expires_at: '',
  is_active: true,
};

export default function AccessTokensPage() {
  const { toast } = useToast();
  const [tokens, setTokens] = useState<AccessToken[]>([]);
  const [profiles, setProfiles] = useState<AccessProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [genOpen, setGenOpen] = useState(false);
  const [form, setForm] = useState<TokenForm>(defaultForm);
  const [generated, setGenerated] = useState<string[]>([]);
  const [detailItem, setDetailItem] = useState<AccessToken | null>(null);
  const [redemptions, setRedemptions] = useState<TokenRedemption[]>([]);
  const [redemptionsLoading, setRedemptionsLoading] = useState(false);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [tokenData, profileData] = await Promise.all([
        api.get<{ items: AccessToken[] }>('/api/admin/tokens'),
        api.get<{ items: AccessProfile[] }>('/api/admin/access-profiles'),
      ]);
      setTokens(tokenData.items || []);
      setProfiles(profileData.items || []);
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const handleGenerate = async () => {
    if (!form.name.trim()) {
      toast('Name is required', 'err');
      return;
    }
    try {
      const body: Record<string, unknown> = {
        name: form.name.trim(),
        description: form.description.trim(),
        prefix: form.prefix.trim() || 'TKN',
        count: form.count,
        profile_key: form.profile_key || null,
        grant_target_type: form.grant_target_type,
        max_redemptions: form.max_redemptions,
        per_install_limit: form.per_install_limit,
        is_active: form.is_active,
      };
      if (form.override_json.trim()) {
        body.override_json = JSON.parse(form.override_json);
      }
      if (form.grant_duration_hours) {
        body.grant_duration_hours = parseInt(form.grant_duration_hours, 10);
      }
      if (form.starts_at) body.starts_at = new Date(form.starts_at).toISOString();
      if (form.expires_at) body.expires_at = new Date(form.expires_at).toISOString();

      const data = await api.post<{ tokens: string[] }>('/api/admin/tokens/generate', body);
      setGenerated(data.tokens || []);
      toast(`Generated ${data.tokens?.length || 0} token(s)`, 'ok');
      fetchData();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const toggleToken = async (token: AccessToken) => {
    try {
      await api.patch(`/api/admin/tokens/${token.token_code}`, { is_active: !token.is_active });
      toast(token.is_active ? 'Token disabled' : 'Token enabled', 'ok');
      fetchData();
      if (detailItem?.token_code === token.token_code) {
        setDetailItem({ ...token, is_active: !token.is_active });
      }
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const viewDetail = async (token: AccessToken) => {
    setDetailItem(token);
    setRedemptionsLoading(true);
    try {
      const data = await api.get<{ items: TokenRedemption[] }>(`/api/admin/tokens/${token.token_code}/redemptions`);
      setRedemptions(data.items || []);
    } catch {
      setRedemptions([]);
    } finally {
      setRedemptionsLoading(false);
    }
  };

  const copyGenerated = () => {
    navigator.clipboard.writeText(generated.join('\n')).then(() => toast('Copied', 'ok'));
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Access Tokens</h1>
          <p>{tokens.length} tokens</p>
        </div>
        <button className="btn-ok" onClick={() => {
          setGenOpen(true);
          setForm(defaultForm);
          setGenerated([]);
        }}>Generate Token</button>
      </div>

      {loading ? (
        <div className="loading">Loading tokens...</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Token Code</th>
                <th>Name</th>
                <th>Profile</th>
                <th>Target</th>
                <th>Redeemed</th>
                <th>Status</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {tokens.length === 0 && (
                <tr><td colSpan={8} className="empty-state">No tokens</td></tr>
              )}
              {tokens.map(t => (
                <tr key={t.token_code}>
                  <td className="mono">{t.token_code}</td>
                  <td>{t.name}</td>
                  <td className="mono" style={{ fontSize: 11 }}>{t.profile_key || 'custom'}</td>
                  <td>{t.grant_target_type}</td>
                  <td>{t.redemption_count}/{t.max_redemptions}</td>
                  <td>
                    <span className={`badge ${t.is_active ? 'badge-active' : 'badge-inactive'}`}>
                      {t.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td style={{ fontSize: 11 }}>{new Date(t.created_at).toLocaleDateString()}</td>
                  <td>
                    <div className="actions-cell">
                      <button className="btn-sm" onClick={() => viewDetail(t)}>Detail</button>
                      <button className={`btn-sm ${t.is_active ? 'btn-danger' : 'btn-ok'}`} onClick={() => toggleToken(t)}>
                        {t.is_active ? 'Disable' : 'Enable'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Generate modal */}
      <Modal open={genOpen} onClose={() => setGenOpen(false)} title="Generate Access Token" wide>
        {generated.length > 0 ? (
          <div>
            <p style={{ color: 'var(--ok)', marginBottom: 8 }}>{generated.length} token(s) generated:</p>
            <div className="code-box">{generated.join('\n')}</div>
            <div className="form-actions">
              <button className="btn-ok" onClick={copyGenerated}>Copy All</button>
              <button onClick={() => { setGenerated([]); setForm(defaultForm); }}>Generate More</button>
              <button onClick={() => setGenOpen(false)}>Close</button>
            </div>
          </div>
        ) : (
          <div>
            <div className="form-row">
              <div className="form-group">
                <label>Name *</label>
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g. QA Weekend Access" autoFocus />
              </div>
              <div className="form-group">
                <label>Description</label>
                <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="Optional description" />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Prefix</label>
                <input value={form.prefix} onChange={(e) => setForm({ ...form, prefix: e.target.value.toUpperCase() })} />
              </div>
              <div className="form-group">
                <label>Count (1–500)</label>
                <input type="number" value={form.count} onChange={(e) => setForm({ ...form, count: parseInt(e.target.value) || 1 })} min={1} max={500} />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Profile Key</label>
                <select value={form.profile_key} onChange={(e) => setForm({ ...form, profile_key: e.target.value })}>
                  <option value="">— Custom override_json —</option>
                  {profiles.filter(p => p.is_active).map(p => (
                    <option key={p.profile_key} value={p.profile_key}>{p.profile_key}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>Grant Target Type</label>
                <select value={form.grant_target_type} onChange={(e) => setForm({ ...form, grant_target_type: e.target.value })}>
                  <option value="install_id">Install ID</option>
                  <option value="player_id">Player ID</option>
                </select>
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Max Redemptions</label>
                <input type="number" value={form.max_redemptions} onChange={(e) => setForm({ ...form, max_redemptions: parseInt(e.target.value) || 1 })} min={1} />
              </div>
              <div className="form-group">
                <label>Per Install Limit</label>
                <input type="number" value={form.per_install_limit} onChange={(e) => setForm({ ...form, per_install_limit: parseInt(e.target.value) || 1 })} min={1} />
              </div>
              <div className="form-group">
                <label>Grant Duration (hours)</label>
                <input value={form.grant_duration_hours} onChange={(e) => setForm({ ...form, grant_duration_hours: e.target.value })} placeholder="Leave empty for permanent" />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Starts At</label>
                <input type="datetime-local" value={form.starts_at} onChange={(e) => setForm({ ...form, starts_at: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Expires At</label>
                <input type="datetime-local" value={form.expires_at} onChange={(e) => setForm({ ...form, expires_at: e.target.value })} />
              </div>
            </div>
            <div className="form-group json-editor">
              <label>Custom Override JSON (optional, overrides profile)</label>
              <textarea
                value={form.override_json}
                onChange={(e) => setForm({ ...form, override_json: e.target.value })}
                placeholder='{"mode":"full","enabled_levels":"all","max_wave":60,...}'
                rows={4}
              />
            </div>
            <div className="checkbox-group" style={{ marginBottom: 12 }}>
              <label><input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Active</label>
            </div>
            <div className="form-actions">
              <button className="btn-ok" onClick={handleGenerate}>Generate</button>
              <button onClick={() => setGenOpen(false)}>Cancel</button>
            </div>
          </div>
        )}
      </Modal>

      {/* Token detail modal */}
      <Modal open={!!detailItem} onClose={() => setDetailItem(null)} title={`Token: ${detailItem?.token_code}`} wide>
        {detailItem && (
          <div>
            <div className="kv-grid" style={{ marginBottom: 16 }}>
              <div className="k">Token Code</div><div className="v mono">{detailItem.token_code}</div>
              <div className="k">Name</div><div className="v">{detailItem.name}</div>
              <div className="k">Description</div><div className="v">{detailItem.description || '—'}</div>
              <div className="k">Profile</div><div className="v mono">{detailItem.profile_key || 'custom'}</div>
              <div className="k">Target Type</div><div className="v">{detailItem.grant_target_type}</div>
              <div className="k">Redemptions</div><div className="v">{detailItem.redemption_count}/{detailItem.max_redemptions}</div>
              <div className="k">Per Install Limit</div><div className="v">{detailItem.per_install_limit}</div>
              <div className="k">Expires</div><div className="v">{detailItem.expires_at ? new Date(detailItem.expires_at).toLocaleString() : 'Never'}</div>
              <div className="k">Created</div><div className="v">{new Date(detailItem.created_at).toLocaleString()}</div>
              <div className="k">Status</div>
              <div className="v">
                <span className={`badge ${detailItem.is_active ? 'badge-active' : 'badge-inactive'}`}>
                  {detailItem.is_active ? 'Active' : 'Inactive'}
                </span>
              </div>
            </div>
            <div className="form-actions">
              <button className={`btn-sm ${detailItem.is_active ? 'btn-danger' : 'btn-ok'}`} onClick={() => toggleToken(detailItem)}>
                {detailItem.is_active ? 'Disable Token' : 'Enable Token'}
              </button>
            </div>

            <h3 style={{ marginTop: 20, marginBottom: 8, color: 'var(--ink3)', fontSize: 11, letterSpacing: '.06em' }}>
              REDEMPTION HISTORY ({redemptions.length})
            </h3>
            {redemptionsLoading ? (
              <div className="loading">Loading redemptions...</div>
            ) : redemptions.length === 0 ? (
              <div className="empty-state">No redemptions yet</div>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Install ID</th>
                      <th>Runtime ID</th>
                      <th>Player ID</th>
                      <th>Redeemed At</th>
                    </tr>
                  </thead>
                  <tbody>
                    {redemptions.map(r => (
                      <tr key={r.id}>
                        <td className="mono truncate" style={{ maxWidth: 120 }}>{r.install_id}</td>
                        <td className="mono truncate" style={{ maxWidth: 120 }}>{r.runtime_id || '—'}</td>
                        <td className="mono">{r.player_id || '—'}</td>
                        <td>{new Date(r.redeemed_at).toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}
