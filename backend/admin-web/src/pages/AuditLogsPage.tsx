import { useCallback, useEffect, useState } from 'react';
import { api, type AuditLog } from '../api/client';
import { useToast } from '../context/ToastContext';
import DataTable from '../components/DataTable';

export default function AuditLogsPage() {
  const { toast } = useToast();
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get<{ items: AuditLog[] }>('/api/admin/audit-logs');
      setLogs(data.items || []);
    } catch (e: unknown) {
      toast((e as Error).message, 'err');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => { fetchLogs(); }, [fetchLogs]);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Audit Logs</h1>
          <p>Recent admin actions</p>
        </div>
        <button onClick={fetchLogs}>Refresh</button>
      </div>

      <DataTable<AuditLog>
        columns={[
          {
            key: 'created_at',
            label: 'Timestamp',
            render: (r) => <span style={{ fontSize: 11 }}>{new Date(r.created_at).toLocaleString()}</span>,
          },
          {
            key: 'action',
            label: 'Action',
            render: (r) => (
              <span className={`badge ${r.action.includes('generated') ? 'badge-ok' : r.action.includes('disabled') || r.action.includes('deleted') ? 'badge-demo' : 'badge-custom'}`}>
                {r.action}
              </span>
            ),
          },
          {
            key: 'target_type',
            label: 'Target Type',
            render: (r) => <span className="mono" style={{ fontSize: 11 }}>{r.target_type || '—'}</span>,
          },
          {
            key: 'target_value',
            label: 'Target',
            render: (r) => <span className="mono truncate" style={{ maxWidth: 160, display: 'inline-block' }}>{r.target_value || '—'}</span>,
          },
          { key: 'actor', label: 'Actor' },
          {
            key: 'metadata',
            label: 'Metadata',
            render: (r) => {
              if (!r.metadata) return '—';
              try {
                const m = JSON.parse(r.metadata);
                return (
                  <pre style={{ background: 'var(--bg0)', padding: '2px 6px', fontSize: 10, maxHeight: 60, overflow: 'auto', margin: 0 }}>
                    {JSON.stringify(m, null, 2)}
                  </pre>
                );
              } catch {
                return <span style={{ fontSize: 10, color: 'var(--ink3)' }}>{r.metadata}</span>;
              }
            },
          },
        ]}
        rows={logs}
        rowKey={(r) => String(r.id)}
        loading={loading}
        emptyMessage="No audit logs yet"
      />
    </div>
  );
}
