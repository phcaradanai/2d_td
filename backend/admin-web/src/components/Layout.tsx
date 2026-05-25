import { NavLink, Outlet } from 'react-router-dom';
import { useCallback, useEffect, useState } from 'react';
import { api, getToken, setToken, ApiError } from '../api/client';
import { useToast } from '../context/ToastContext';

type ApiStatus = 'checking' | 'online' | 'offline';

export default function Layout() {
  const { toast } = useToast();
  const [status, setStatus] = useState<ApiStatus>('checking');
  const [tokenInput, setTokenInput] = useState(getToken());

  const checkHealth = useCallback(async () => {
    try {
      const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || ''}/health`);
      if (res.ok) {
        setStatus('online');
      } else {
        setStatus('offline');
      }
    } catch {
      setStatus('offline');
    }
  }, []);

  useEffect(() => {
    checkHealth();
    const interval = setInterval(checkHealth, 30000);
    return () => clearInterval(interval);
  }, [checkHealth]);

  const handleSaveToken = () => {
    setToken(tokenInput);
    toast('Admin token saved', 'ok');
  };

  const handleClearToken = () => {
    setToken('');
    setTokenInput('');
    toast('Admin token cleared', 'ok');
  };

  const verifyToken = async () => {
    try {
      await api.get('/api/admin/dashboard/summary');
      toast('Token is valid', 'ok');
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        toast('Invalid admin token', 'err');
      } else {
        toast('API unreachable', 'err');
      }
    }
  };

  const navItems = [
    { to: '/', label: 'Overview', icon: '◆' },
    { to: '/runtimes', label: 'Runtime Access', icon: '◇' },
    { to: '/profiles', label: 'Access Profiles', icon: '○' },
    { to: '/tokens', label: 'Access Tokens', icon: '¤' },
    { to: '/audit-logs', label: 'Audit Logs', icon: '▹' },
    { to: '/files', label: 'Files & Assets', icon: '◫' },
  ];

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="sidebar-logo">
          <h1>Tower Defense</h1>
          <p>Admin Dashboard</p>
        </div>
        <nav className="sidebar-nav">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      <div className="main-area">
        <header className="topbar">
          <span className="topbar-title">Tower Defense Admin</span>
          <span className={`api-status ${status}`}>
            {status === 'checking' ? 'Checking...' : status === 'online' ? 'API Online' : 'API Offline'}
          </span>
          <div className="token-bar">
            <label>Token:</label>
            <input
              type="password"
              value={tokenInput}
              onChange={(e) => setTokenInput(e.target.value)}
              placeholder="Enter admin token"
            />
            <button className="btn-sm btn-ok" onClick={handleSaveToken}>Save</button>
            <button className="btn-sm" onClick={verifyToken}>Test</button>
            <button className="btn-sm btn-danger" onClick={handleClearToken}>Clear</button>
          </div>
        </header>

        <main className="page-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
