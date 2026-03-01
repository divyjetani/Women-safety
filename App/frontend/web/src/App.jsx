import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Dashboard from './pages/Dashboard';
import LiveTracking from './pages/LiveTracking';
import SafeRoutes from './pages/SafeRoutes';
import EmergencyContacts from './pages/EmergencyContacts';
import IncidentMap from './pages/IncidentMap';
import Analytics from './pages/Analytics';
import Settings from './pages/Settings';
import Profile from './pages/Profile';
import AIAssistant from './pages/AIAssistant';
import './App.css';

function App() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [emergencyMode, setEmergencyMode] = useState(false);

  // Listen for emergency triggers
  useEffect(() => {
    const handleEmergency = (e) => {
      if (e.detail?.emergency) {
        setEmergencyMode(true);
        // Backend API call will go here
        // await fetch('/api/emergency/trigger', { method: 'POST', ... })
      }
    };

    window.addEventListener('emergency-triggered', handleEmergency);
    return () => window.removeEventListener('emergency-triggered', handleEmergency);
  }, []);

  return (
    <Router>
      <div className="app-container">
        {emergencyMode && (
          <div className="emergency-banner">
            <div className="emergency-pulse"></div>
            <span>🚨 EMERGENCY MODE ACTIVE - Help is on the way</span>
            <button onClick={() => setEmergencyMode(false)}>Cancel</button>
          </div>
        )}
        
        <Sidebar isOpen={sidebarOpen} toggleSidebar={() => setSidebarOpen(!sidebarOpen)} />
        
        <main className={`main-content ${sidebarOpen ? 'sidebar-open' : 'sidebar-closed'}`}>
          <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/tracking" element={<LiveTracking />} />
            <Route path="/safe-routes" element={<SafeRoutes />} />
            <Route path="/contacts" element={<EmergencyContacts />} />
            <Route path="/incident-map" element={<IncidentMap />} />
            <Route path="/analytics" element={<Analytics />} />
            <Route path="/ai-assistant" element={<AIAssistant />} />
            <Route path="/settings" element={<Settings />} />
            <Route path="/profile" element={<Profile />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
