import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';
import { authAPI, notificationAPI } from '../services/api';
import toast from 'react-hot-toast';

const AuthContext = createContext(null);
const WS_URL = process.env.REACT_APP_WS_URL || 'http://localhost:8080/ws';

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem('user')); } catch { return null; }
  });
  const [loading, setLoading]   = useState(false);
  const [unreadCount, setUnread] = useState(0);
  const [notifications, setNotifications] = useState([]);
  const stompRef = useRef(null);

  const fetchUnread = useCallback(async () => {
    try {
      const res = await notificationAPI.getUnreadCount();
      setUnread(res.data.count);
    } catch {}
  }, []);

  const connectWS = useCallback((username) => {
    if (stompRef.current?.active) return;
    const token = localStorage.getItem('accessToken');
    const client = new Client({
      webSocketFactory: () => new SockJS(WS_URL),
      connectHeaders: { Authorization: `Bearer ${token}` },
      reconnectDelay: 5000,
      onConnect: () => {
        client.subscribe(`/user/${username}/queue/notifications`, (msg) => {
          try {
            const notif = JSON.parse(msg.body);
            setNotifications(prev => [notif, ...prev]);
            setUnread(prev => prev + 1);
            toast.custom(() => (
              <div style={{
                background:'var(--bg-card)', border:'1px solid var(--accent)',
                borderRadius:10, padding:'12px 16px', maxWidth:320,
                boxShadow:'0 0 30px rgba(108,99,255,0.3)',
              }}>
                <div style={{fontSize:13,fontWeight:600,color:'var(--accent)',marginBottom:4}}>{notif.title}</div>
                <div style={{fontSize:12,color:'var(--text-secondary)'}}>{notif.message}</div>
              </div>
            ), { duration: 5000, position: 'top-right' });
          } catch {}
        });
      },
    });
    client.activate();
    stompRef.current = client;
  }, []);

  const disconnectWS = useCallback(() => {
    if (stompRef.current?.active) stompRef.current.deactivate();
    stompRef.current = null;
  }, []);

  useEffect(() => {
    if (user) { fetchUnread(); connectWS(user.username); }
  }, [user, fetchUnread, connectWS]);

  const login = async (credentials) => {
    setLoading(true);
    try {
      const res = await authAPI.login(credentials);
      const { accessToken, refreshToken, user: userData } = res.data;
      localStorage.setItem('accessToken', accessToken);
      localStorage.setItem('refreshToken', refreshToken);
      localStorage.setItem('user', JSON.stringify(userData));
      setUser(userData);
      connectWS(userData.username);
      return userData;
    } finally { setLoading(false); }
  };

  const logout = () => {
    disconnectWS();
    localStorage.clear();
    setUser(null); setUnread(0); setNotifications([]);
  };

  return (
    <AuthContext.Provider value={{
      user, loading, unreadCount, setUnread, notifications, setNotifications,
      login, logout, fetchUnread,
      isAdmin:   user?.role === 'ADMIN',
      isManager: user?.role === 'MANAGER',
      isUser:    user?.role === 'USER',
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
};
