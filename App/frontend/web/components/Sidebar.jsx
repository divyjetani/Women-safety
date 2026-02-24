import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { 
  LayoutDashboard, 
  MapPin, 
  Route, 
  Users, 
  Map, 
  BarChart3, 
  Settings, 
  User,
  Sparkles,
  Shield,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
import './Sidebar.css';

const Sidebar = ({ isOpen, toggleSidebar }) => {
  const location = useLocation();

  const navItems = [
    { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    { path: '/tracking', icon: MapPin, label: 'Live Tracking' },
    { path: '/safe-routes', icon: Route, label: 'Safe Routes' },
    { path: '/contacts', icon: Users, label: 'Emergency Contacts' },
    { path: '/incident-map', icon: Map, label: 'Incident Map' },
    { path: '/analytics', icon: BarChart3, label: 'Analytics' },
    { path: '/ai-assistant', icon: Sparkles, label: 'AI Assistant' },
  ];

  const bottomNavItems = [
    { path: '/settings', icon: Settings, label: 'Settings' },
    { path: '/profile', icon: User, label: 'Profile' },
  ];

  return (
    <aside className={`sidebar ${isOpen ? 'open' : 'closed'}`}>
      <div className="sidebar-header">
        <div className="logo-container">
          <div className="logo-icon">
            <Shield className="shield-icon" />
          </div>
          {isOpen && (
            <div className="logo-text">
              <h1>SafeGuard</h1>
              <p>Women Safety Analytics</p>
            </div>
          )}
        </div>
        <button className="toggle-btn" onClick={toggleSidebar}>
          {isOpen ? <ChevronLeft size={20} /> : <ChevronRight size={20} />}
        </button>
      </div>

      <nav className="sidebar-nav">
        <ul>
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <li key={item.path}>
                <Link 
                  to={item.path} 
                  className={`nav-link ${isActive ? 'active' : ''}`}
                >
                  <Icon size={22} />
                  {isOpen && <span>{item.label}</span>}
                  {isActive && <div className="active-indicator" />}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="sidebar-footer">
        <ul>
          {bottomNavItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <li key={item.path}>
                <Link 
                  to={item.path} 
                  className={`nav-link ${isActive ? 'active' : ''}`}
                >
                  <Icon size={22} />
                  {isOpen && <span>{item.label}</span>}
                  {isActive && <div className="active-indicator" />}
                </Link>
              </li>
            );
          })}
        </ul>
      </div>
    </aside>
  );
};

export default Sidebar;
