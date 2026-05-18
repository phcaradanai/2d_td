import { useEffect, useState } from 'react';
import { api, type DashboardSummary, type RuntimeInstance } from '../api/client';
import { useToast } from '../context/ToastContext';
import StatCard from '../components/StatCard';
import DataTable from '../components/DataTable';

export default function DashboardPage() {
  const { toast } = useToast();
  const [data, setData] = useState<DashboardSummary | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get<DashboardSummary>('/api/admin/dashboard/summary')
      .then(setData)
      .catch((e) => toast(e.message, 'err'))
      .finally(() => setLoading(false));
  }, [toast]);

  if (loading) return <div className="loading">Loading dashboard...</div>;
  if (!data) return <div className="err-msg">Failed to load dashboard</div>;

  const modeCards = Object.entries(data.mode_breakdown || {}).map(([mode, count]) => (
    <StatCard key={mode} label={`${mode} installs`} value={count} />
  ));

  const platformItems = Object.entries(data.platform_breakdown || {});
  const buildItems = Object.entries(data.build_breakdown || {});

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Dashboard Overview</h1>
          <p>Real-time install and access summary</p>
        </div>
      </div>

      <div className="stat-grid">
        <StatCard label="Total Installs" value={data.total_installs} />
        <StatCard label="Runtime Sessions" value={data.runtime_sessions} />
        <StatCard label="Active 24h" value={data.active_24h} />
        <StatCard label="Active 7d" value={data.active_7d} />
        <StatCard label="Active Tokens" value={data.active_tokens} />
        <StatCard label="Total Redemptions" value={data.total_redemptions} />
        <StatCard label="Leaderboard Subs" value={data.leaderboard_submissions} />
        {modeCards}
      </div>

      <div className="breakdown-grid">
        <div className="breakdown-card">
          <h3>Platform Breakdown</h3>
          {platformItems.length === 0 && <div className="empty-state">No data</div>}
          {platformItems.map(([k, v]) => (
            <div key={k} className="breakdown-item">
              <span>{k}</span>
              <span>{v}</span>
            </div>
          ))}
        </div>
        <div className="breakdown-card">
          <h3>Build Breakdown</h3>
          {buildItems.length === 0 && <div className="empty-state">No data</div>}
          {buildItems.map(([k, v]) => (
            <div key={k} className="breakdown-item">
              <span>{k}</span>
              <span>{v}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title">Recent Installs</div>
        <DataTable<RuntimeInstance>
          columns={[
            { key: 'install_id', label: 'Install ID', render: (r) => <span className="mono truncate" style={{maxWidth:120,display:'inline-block'}}>{r.install_id}</span> },
            { key: 'build_id', label: 'Build' },
            { key: 'platform', label: 'Platform' },
            { key: 'access_mode', label: 'Mode', render: (r) => r.access_mode ? <span className={`badge badge-${r.access_mode}`}>{r.access_mode}</span> : '—' },
            { key: 'last_seen_at', label: 'Last Seen', render: (r) => new Date(r.last_seen_at).toLocaleString() },
          ]}
          rows={data.recent_installs || []}
          rowKey={(r) => r.runtime_id}
          emptyMessage="No recent installs"
        />
      </div>

      <div className="card">
        <div className="card-title">Recent Token Redemptions</div>
        <DataTable<{ token_code: string; install_id: string; redeemed_at: string }>
          columns={[
            { key: 'token_code', label: 'Token', render: (r) => <span className="mono">{r.token_code}</span> },
            { key: 'install_id', label: 'Install ID', render: (r) => <span className="mono truncate" style={{maxWidth:120,display:'inline-block'}}>{r.install_id}</span> },
            { key: 'redeemed_at', label: 'Redeemed At', render: (r) => new Date(r.redeemed_at).toLocaleString() },
          ]}
          rows={data.recent_redemptions || []}
          rowKey={(r) => `${r.token_code}-${r.install_id}`}
          emptyMessage="No recent redemptions"
        />
      </div>
    </div>
  );
}
