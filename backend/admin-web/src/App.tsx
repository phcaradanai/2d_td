import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import DashboardPage from './pages/DashboardPage';
import RuntimeAccessPage from './pages/RuntimeAccessPage';
import InstallDetailPage from './pages/InstallDetailPage';
import AccessProfilesPage from './pages/AccessProfilesPage';
import AccessTokensPage from './pages/AccessTokensPage';
import AuditLogsPage from './pages/AuditLogsPage';
import FilesPage from './pages/FilesPage';

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<DashboardPage />} />
        <Route path="runtimes" element={<RuntimeAccessPage />} />
        <Route path="installs/:installId" element={<InstallDetailPage />} />
        <Route path="profiles" element={<AccessProfilesPage />} />
        <Route path="tokens" element={<AccessTokensPage />} />
        <Route path="audit-logs" element={<AuditLogsPage />} />
        <Route path="files" element={<FilesPage />} />
      </Route>
    </Routes>
  );
}
