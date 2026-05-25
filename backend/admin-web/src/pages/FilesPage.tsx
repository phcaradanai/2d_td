import React, { useEffect, useState, useRef } from 'react';
import { fileApi, UploadedFile, ApiError } from '../api/client';
import { useToast } from '../context/ToastContext';

export default function FilesPage() {
  const { toast } = useToast();
  const [files, setFiles] = useState<UploadedFile[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchFiles = async () => {
    setLoading(true);
    try {
      const data = await fileApi.list();
      setFiles(data || []);
    } catch (e) {
      if (e instanceof ApiError) {
        toast(`Failed to load files: ${e.message}`, 'err');
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchFiles();
  }, []);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0) return;
    const file = e.target.files[0];
    
    setUploading(true);
    try {
      await fileApi.upload(file);
      toast('File uploaded successfully', 'ok');
      fetchFiles();
    } catch (err) {
      if (err instanceof ApiError) {
        toast(`Upload failed: ${err.message}`, 'err');
      } else {
        toast('Upload failed', 'err');
      }
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this file?')) return;
    try {
      await fileApi.delete(id);
      toast('File deleted', 'ok');
      fetchFiles();
    } catch (err) {
      if (err instanceof ApiError) {
        toast(`Delete failed: ${err.message}`, 'err');
      }
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text).then(() => {
      toast('URL copied to clipboard', 'ok');
    });
  };

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h2>Files & Assets</h2>
        <div>
          <input 
            type="file" 
            style={{ display: 'none' }} 
            ref={fileInputRef} 
            onChange={handleFileChange} 
          />
          <button 
            className="btn btn-primary" 
            disabled={uploading}
            onClick={() => fileInputRef.current?.click()}
          >
            {uploading ? 'Uploading...' : '+ Upload File'}
          </button>
        </div>
      </div>

      {loading ? (
        <p>Loading files...</p>
      ) : files.length === 0 ? (
        <div className="card" style={{ padding: '2rem', textAlign: 'center', opacity: 0.7 }}>
          <p>No files uploaded yet.</p>
        </div>
      ) : (
        <div className="card table-responsive">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Filename</th>
                <th>Size</th>
                <th>Uploaded At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {files.map(f => (
                <tr key={f.id}>
                  <td>{f.id}</td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{f.filename}</div>
                    <div style={{ fontSize: '0.85em', color: '#888', wordBreak: 'break-all' }}>
                      {f.download_url}
                    </div>
                  </td>
                  <td>{formatBytes(f.size_bytes)}</td>
                  <td>{new Date(f.created_at).toLocaleString()}</td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button 
                        className="btn-sm btn-ok" 
                        onClick={() => copyToClipboard(f.download_url)}
                      >
                        Copy Link
                      </button>
                      <button 
                        className="btn-sm btn-danger" 
                        onClick={() => handleDelete(f.id)}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
