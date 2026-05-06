import axios from 'axios';

const API_BASE = process.env.REACT_APP_API_URL || 'http://34.226.199.223:8080';

const api = axios.create({
  baseURL: `${API_BASE}/api`,
  headers: { 'Content-Type': 'application/json' },
});

// Request interceptor — attach token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('accessToken');
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor — handle 401
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.clear();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// ── AUTH ──────────────────────────────────────────────
export const authAPI = {
  login: (data) => api.post('/auth/login', data),
};

// ── USERS ─────────────────────────────────────────────
export const userAPI = {
  getMe:          ()        => api.get('/users/me'),
  getAll:         ()        => api.get('/admin/users'),
  getByRole:      (role)    => api.get(`/admin/users/role/${role}`),
  getById:        (id)      => api.get(`/admin/users/${id}`),
  create:         (data)    => api.post('/admin/users', data),
  update:         (id, data)=> api.put(`/admin/users/${id}`, data),
  delete:         (id)      => api.delete(`/admin/users/${id}`),
  getManagers:    ()        => api.get('/users/managers'),
  getMembers:     ()        => api.get('/users/members'),
};

// ── PROJECTS ──────────────────────────────────────────
export const projectAPI = {
  getAll:         ()                  => api.get('/projects'),
  getById:        (id)                => api.get(`/projects/${id}`),
  create:         (data)              => api.post('/projects', data),
  update:         (id, data)          => api.put(`/projects/${id}`, data),
  delete:         (id)                => api.delete(`/projects/${id}`),
  assignMembers:  (id, data)          => api.post(`/projects/${id}/members`, data),
  removeMember:   (id, userId)        => api.delete(`/projects/${id}/members/${userId}`),
};

// ── TASKS ─────────────────────────────────────────────
export const taskAPI = {
  getAll:         ()        => api.get('/tasks'),
  getByProject:   (pid)     => api.get(`/tasks/project/${pid}`),
  create:         (data)    => api.post('/tasks', data),
  update:         (id, data)=> api.put(`/tasks/${id}`, data),
  delete:         (id)      => api.delete(`/tasks/${id}`),

   // 🔥 STATUS UPDATE
  updateStatus: (taskId, status) =>
    api.put(`/tasks/${taskId}/status?status=${status}`),

  // 🔥 VERSION CONTROL (Task History)
getHistory: (taskId) => api.get(`/tasks/${taskId}/history`),

restoreHistory: (taskId, historyId) => api.post(`/tasks/${taskId}/history/${historyId}/restore`),
  //10 April
};

// ── NOTIFICATIONS ─────────────────────────────────────
/*export const notificationAPI = {
  getAll:         (page=0, size=20)   => api.get(`/notifications?page=${page}&size=${size}`),
  getUnreadCount: ()                  => api.get('/notifications/unread-count'),
  markAsRead:     (id)                => api.patch(`/notifications/${id}/read`),
  markAllAsRead:  ()                  => api.patch('/notifications/read-all'),
};*/

// ── NOTIFICATIONS ─────────────────────────────────────
// ── NOTIFICATIONS ─────────────────────────────────────
export const notificationAPI = {
  getAll:         (page=0, size=20)   => api.get(`/notifications?page=${page}&size=${size}`),
  getAllUnpaged:   ()                  => api.get('/notifications/all'),       // ← ADD
  getRead:        ()                  => api.get('/notifications/read'),       // ← ADD
  getUnread:      ()                  => api.get('/notifications/unread'),     // ← ADD
  getUnreadCount: ()                  => api.get('/notifications/unread-count'),
  markAsRead:     (id)                => api.patch(`/notifications/${id}/read`),
  markAllAsRead:  ()                  => api.patch('/notifications/read-all'),
};

// ── AUDIT LOGS ────────────────────────────────────────
export const auditAPI = {
  getAll:     (page=0, size=20)           => api.get(`/audit-logs?page=${page}&size=${size}`),
  getByType:  (type, page=0, size=20)     => api.get(`/audit-logs/entity/${type}?page=${page}&size=${size}`),
};

export const reportAPI = {
  getAllEmployees: () => api.get('/admin/reports/employees'),
  getEmployee:    (id) => api.get(`/admin/reports/employees/${id}`),
};

export default api;
