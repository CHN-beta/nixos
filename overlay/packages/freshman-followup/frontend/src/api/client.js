const BASE_URL = '/api';

export class ApiError extends Error {
  constructor(message, status, data) {
    super(message);
    this.status = status;
    this.data = data;
  }
}

async function request(endpoint, options = {}) {
  const token = localStorage.getItem('token');
  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    ...options.headers,
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    if (!window.location.pathname.includes('/login')) {
      window.location.href = '/ui/login';
    }
  }

  let data = null;
  const contentType = response.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    data = await response.json().catch(() => null);
  } else {
    data = await response.text().catch(() => null);
  }

  if (!response.ok) {
    const errorMsg = data?.error || (typeof data === 'string' ? data : '请求失败');
    throw new ApiError(errorMsg, response.status, data);
  }

  return data;
}

export const api = {
  // 认证
  login: (username, password) =>
    request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),

  getMe: () => request('/auth/me'),

  // 可选排班日期
  getAvailableDates: () => request('/available-dates'),

  // 老师排班
  getSchedules: (date) => request(`/schedules?date=${encodeURIComponent(date)}`),

  createSchedule: (payload) =>
    request('/schedules', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  deleteSchedule: (id) =>
    request(`/schedules/${id}`, {
      method: 'DELETE',
    }),

  // 学生与回访
  getColleges: () => request('/colleges'),

  getStudents: (params = {}) => {
    const q = new URLSearchParams();
    if (params.search) q.append('search', params.search);
    if (params.college) q.append('college', params.college);
    if (params.status) q.append('status', params.status);
    if (params.page) q.append('page', params.page);
    if (params.page_size) q.append('page_size', params.page_size);
    return request(`/students?${q.toString()}`);
  },

  getStudent: (id) => request(`/students/${encodeURIComponent(id)}`),

  updateStudentStatus: (id, payload) =>
    request(`/students/${encodeURIComponent(id)}/status`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    }),

  updateStudentRemarks: (id, payload) =>
    request(`/students/${encodeURIComponent(id)}/remarks`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    }),

};
