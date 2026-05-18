const BASE_URL = (import.meta.env.VITE_API_BASE_URL as string) || '';

export function getToken(): string {
  return localStorage.getItem('admin_token') || '';
}

export function setToken(token: string): void {
  if (token) {
    localStorage.setItem('admin_token', token);
  } else {
    localStorage.removeItem('admin_token');
  }
}

class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${getToken()}`,
  };

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  let data: Record<string, unknown>;
  try {
    data = await res.json();
  } catch {
    throw new ApiError(res.status, `HTTP ${res.status}: ${res.statusText}`);
  }

  if (!res.ok || data['ok'] === false) {
    const err = data['error'] as { message?: string } | string | undefined;
    const message =
      typeof err === 'object' && err?.message
        ? err.message
        : typeof err === 'string'
        ? err
        : `HTTP ${res.status}`;
    throw new ApiError(res.status, message);
  }

  return data as T;
}

export const api = {
  get:    <T>(path: string)                  => request<T>('GET', path),
  post:   <T>(path: string, body: unknown)   => request<T>('POST', path, body),
  patch:  <T>(path: string, body: unknown)   => request<T>('PATCH', path, body),
  delete: <T>(path: string, body?: unknown)  => request<T>('DELETE', path, body),
};

export { ApiError };

// ── Typed API calls ──────────────────────────────────────────────────────────

export interface AccessConfig {
  mode: string;
  enabled_levels: number[] | 'all';
  max_wave: number;
  allow_leaderboard_submit: boolean;
  allow_save_resume: boolean;
  allow_sandbox: boolean;
  allow_challenge_mode: boolean;
  maintenance_enabled?: boolean;
  force_update?: boolean;
  announcement?: string;
}

export interface ResolvedAccess {
  config_version: number;
  resolved_from: string;
  profile_key: string;
  tags: string[];
  config: AccessConfig;
}

export interface RuntimeInstance {
  runtime_id: string;
  install_id: string;
  player_id: string | null;
  build_id: string;
  platform: string;
  game_version: string | null;
  access_mode: string | null;
  config_version: number;
  resolved_from: string | null;
  tags: string[];
  last_seen_at: string;
  created_at: string;
}

export interface AccessProfile {
  id: number;
  profile_key: string;
  name: string;
  config_json: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface AccessOverride {
  id: number;
  target_type: string;
  target_value: string;
  profile_key: string | null;
  override_json: string | null;
  priority: number;
  is_active: boolean;
  starts_at: string | null;
  ends_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface AccessToken {
  token_code: string;
  name: string;
  description: string;
  profile_key: string | null;
  grant_target_type: string;
  max_redemptions: number;
  per_install_limit: number;
  expires_at: string | null;
  is_active: boolean;
  redemption_count: number;
  created_at: string;
}

export interface TokenRedemption {
  id: number;
  token_code: string;
  install_id: string;
  runtime_id: string | null;
  player_id: string | null;
  redeemed_at: string;
}

export interface AuditLog {
  id: number;
  action: string;
  target_type: string | null;
  target_value: string | null;
  actor: string;
  metadata: string | null;
  created_at: string;
}

export interface DashboardSummary {
  ok: boolean;
  total_installs: number;
  runtime_sessions: number;
  active_24h: number;
  active_7d: number;
  mode_breakdown: Record<string, number>;
  active_tokens: number;
  total_redemptions: number;
  leaderboard_submissions: number;
  platform_breakdown: Record<string, number>;
  build_breakdown: Record<string, number>;
  recent_installs: RuntimeInstance[];
  recent_redemptions: { token_code: string; install_id: string; redeemed_at: string }[];
}
