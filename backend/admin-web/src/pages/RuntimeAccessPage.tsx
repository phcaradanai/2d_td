import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, type RuntimeInstance } from '../api/client';
import { useToast } from '../context/ToastContext';
import DataTable from '../components/DataTable';
import Modal from '../components/Modal';

export default function RuntimeAccessPage() {
  const { toast } = useToast();
  const navigate = useNavigate();
  const [rows, setRows] = useState<RuntimeInstance[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [modeFilter, setModeFilter] = useState('');
  const [tagFilter, setTagFilter] = useState('');
  const [page, setPage] = useState(0);
  const pageSize = 50;

  // Tag modal state
  const [tagModal, setTagModal] = useState<{ targetType: string; targetValue: string } | null>(null);
  const [tagInput, setTagInput] = useState('');

  const fetchRuntimes = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (search) params.set('q', search);
      if (modeFilter) params.set('mode', modeFilter);
      if (tagFilter) params.set('tag', tagFilter);
      params.set('limit', String(pageSize));
      params.set('offset', String(page * pageSize));

      const data = await api.get<{ items: RuntimeInstance[]; total: number }>(`/api/admin/runtimes?${params}`);
      setRows(data.items || []);
      setTotal(data.total || 0);
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    } finally {
      setLoading(false);
    }
  }, [search, modeFilter, tagFilter, page, toast]);

  useEffect(() => { fetchRuntimes(); }, [fetchRuntimes]);

  const setAccess = async (targetType: string, targetValue: string, profileKey: string) => {
    try {
      const endpoint = targetType === 'install_id'
        ? `/api/admin/installations/${targetValue}/access`
        : `/api/admin/runtimes/${targetValue}/access`;
      await api.patch(endpoint, { profile_key: profileKey });
      toast(`Set ${targetValue} to ${profileKey}`, 'ok');
      fetchRuntimes();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const addTag = async () => {
    if (!tagModal || !tagInput.trim()) return;
    try {
      await api.post('/api/admin/tags', { target_type: tagModal.targetType, target_value: tagModal.targetValue, tag: tagInput.trim().toLowerCase() });
      toast('Tag added', 'ok');
      setTagModal(null);
      setTagInput('');
      fetchRuntimes();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const removeTag = async (targetType: string, targetValue: string, tag: string) => {
    try {
      await api.delete('/api/admin/tags', { target_type: targetType, target_value: targetValue, tag });
      toast('Tag removed', 'ok');
      fetchRuntimes();
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    }
  };

  const copyText = (text: string) => {
    navigator.clipboard.writeText(text).then(() => toast('Copied', 'ok'));
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Runtime Access</h1>
          <p>{total} total sessions</p>
        </div>
      </div>

      <div className="filter-bar">
        <input
          placeholder="Search install_id, runtime_id..."
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(0); }}
        />
        <select value={modeFilter} onChange={(e) => { setModeFilter(e.target.value); setPage(0); }}>
          <option value="">All modes</option>
          <option value="demo">Demo</option>
          <option value="full">Full</option>
          <option value="custom">Custom</option>
        </select>
        <input
          placeholder="Filter by tag..."
          value={tagFilter}
          onChange={(e) => { setTagFilter(e.target.value); setPage(0); }}
          style={{ width: 140 }}
        />
        <button onClick={fetchRuntimes}>Refresh</button>
      </div>

      <DataTable<RuntimeInstance>
        columns={[
          {
            key: 'install_id',
            label: 'Install ID',
            render: (r) => (
              <span className="mono truncate" style={{ maxWidth: 100, display: 'inline-block', cursor: 'pointer' }}
                onClick={() => navigate(`/installs/${r.install_id}`)}>
                {r.install_id}
              </span>
            ),
          },
          {
            key: 'runtime_id',
            label: 'Runtime ID',
            render: (r) => <span className="mono truncate" style={{ maxWidth: 100, display: 'inline-block' }}>{r.runtime_id}</span>,
          },
          { key: 'build_id', label: 'Build' },
          { key: 'platform', label: 'Platform' },
          {
            key: 'access_mode',
            label: 'Mode',
            render: (r) => r.access_mode ? <span className={`badge badge-${r.access_mode}`}>{r.access_mode}</span> : '—',
          },
          {
            key: 'resolved_from',
            label: 'Source',
            render: (r) => r.resolved_from ? <span className="badge badge-custom">{r.resolved_from}</span> : '—',
          },
          {
            key: 'tags',
            label: 'Tags',
            render: (r) => (
              <span>
                {r.tags?.map(tag => (
                  <span key={tag} className="tag-chip">
                    {tag}
                    <span className="rm" onClick={() => removeTag('install_id', r.install_id, tag)}>&times;</span>
                  </span>
                ))}
              </span>
            ),
          },
          {
            key: 'last_seen_at',
            label: 'Last Seen',
            render: (r) => new Date(r.last_seen_at).toLocaleString(),
          },
          {
            key: 'actions',
            label: 'Actions',
            render: (r) => (
              <div className="actions-cell">
                <button className="btn-sm btn-ok" onClick={() => setAccess('install_id', r.install_id, 'full')}>Set Full</button>
                <button className="btn-sm btn-primary" onClick={() => setAccess('install_id', r.install_id, 'demo')}>Set Demo</button>
                <button className="btn-sm" onClick={() => setAccess('install_id', r.install_id, 'demo_level_1_wave_20')}>L1 W20</button>
                <button className="btn-sm" onClick={() => setTagModal({ targetType: 'install_id', targetValue: r.install_id })}>+Tag</button>
                <button className="btn-sm" onClick={() => copyText(r.install_id)}>Copy ID</button>
                <button className="btn-sm" onClick={() => navigate(`/installs/${r.install_id}`)}>Detail</button>
              </div>
            ),
          },
        ]}
        rows={rows}
        rowKey={(r) => r.runtime_id}
        loading={loading}
        emptyMessage="No runtime sessions found"
      />

      <div style={{ marginTop: 12, display: 'flex', gap: 8, alignItems: 'center' }}>
        <button disabled={page === 0} onClick={() => setPage(p => p - 1)}>Previous</button>
        <span style={{ color: 'var(--ink3)', fontSize: 12 }}>Page {page + 1}</span>
        <button disabled={rows.length < pageSize} onClick={() => setPage(p => p + 1)}>Next</button>
      </div>

      <Modal open={!!tagModal} onClose={() => setTagModal(null)} title="Add Tag">
        <div className="form-group">
          <label>Tag name</label>
          <input value={tagInput} onChange={(e) => setTagInput(e.target.value)} placeholder="e.g. vip" autoFocus
            onKeyDown={(e) => { if (e.key === 'Enter') addTag(); }} />
        </div>
        <div className="form-actions">
          <button className="btn-ok" onClick={addTag}>Add Tag</button>
          <button onClick={() => setTagModal(null)}>Cancel</button>
        </div>
      </Modal>
    </div>
  );
}
