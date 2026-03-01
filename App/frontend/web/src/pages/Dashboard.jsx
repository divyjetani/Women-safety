import React, { useState, useEffect } from 'react';
import { 
  Shield, 
  MapPin, 
  Users, 
  AlertTriangle, 
  Phone, 
  Camera,
  Mic,
  Battery,
  Clock,
  TrendingUp,
  Activity,
  Bell
} from 'lucide-react';
import EmergencyButton from '../components/EmergencyButton';
import QuickActions from '../components/QuickActions';
import SafetyScore from '../components/SafetyScore';
import RecentAlerts from '../components/RecentAlerts';
import './Dashboard.css';

const Dashboard = () => {
  const [userLocation, setUserLocation] = useState({ lat: 0, lng: 0 });
  const [activeGuardians, setActiveGuardians] = useState(0);
  const [safetyScore, setSafetyScore] = useState(85);
  const [batteryLevel, setBatteryLevel] = useState(75);
  const [isTracking, setIsTracking] = useState(true);

  useEffect(() => {
    // Simulated data - Replace with actual API calls
    // Example: fetch('/api/user/location').then(res => res.json()).then(setUserLocation)
    
    const mockData = async () => {
      setActiveGuardians(5);
      setSafetyScore(85);
    };
    
    mockData();

    // Get battery level
    if ('getBattery' in navigator) {
      navigator.getBattery().then(battery => {
        setBatteryLevel(Math.round(battery.level * 100));
      });
    }
  }, []);

  const stats = [
    {
      icon: Shield,
      label: 'Safety Score',
      value: `${safetyScore}%`,
      trend: '+5%',
      color: 'success',
      description: 'Based on your location'
    },
    {
      icon: Users,
      label: 'Active Guardians',
      value: activeGuardians,
      trend: 'Online',
      color: 'primary',
      description: 'Monitoring your safety'
    },
    {
      icon: MapPin,
      label: 'Location Sharing',
      value: isTracking ? 'Active' : 'Inactive',
      trend: 'Real-time',
      color: 'success',
      description: 'Sharing with trusted contacts'
    },
    {
      icon: Battery,
      label: 'Battery Status',
      value: `${batteryLevel}%`,
      trend: batteryLevel < 20 ? 'Low' : 'Good',
      color: batteryLevel < 20 ? 'warning' : 'success',
      description: 'Device power level'
    }
  ];

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Welcome back, User</h1>
          <p className="page-subtitle">Your safety dashboard is active and monitoring</p>
        </div>
        <div className="header-actions">
          
            <span className="notification-badge">3</span>
          <button className="btn btn-secondary">
            <Bell size={18} />
          </button>
        </div>
      </div>

      {/* Emergency Button - Always Accessible */}
      <EmergencyButton />

      {/* Stats Grid */}
      <div className="stats-grid">
        {stats.map((stat, index) => (
          <div 
            key={index} 
            className={`stat-card stat-${stat.color}`}
            style={{ animationDelay: `${index * 0.1}s` }}
          >
            <div className="stat-icon-wrapper">
              <stat.icon className="stat-icon" />
            </div>
            <div className="stat-content">
              <p className="stat-label">{stat.label}</p>
              <h3 className="stat-value">{stat.value}</h3>
              <div className="stat-footer">
                <span className={`stat-trend trend-${stat.color}`}>
                  <TrendingUp size={14} />
                  {stat.trend}
                </span>
                <span className="stat-description">{stat.description}</span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Main Content Grid */}
      <div className="dashboard-grid">
        {/* Left Column */}
        <div className="dashboard-column">
          <SafetyScore score={safetyScore} />
          <QuickActions />
        </div>

        {/* Right Column */}
        <div className="dashboard-column">
          <RecentAlerts />
          
          {/* Active Features */}
          <div className="card active-features-card">
            <div className="card-header">
              <h3>Active Safety Features</h3>
              <Activity size={20} />
            </div>
            <div className="features-list">
              <div className="feature-item active">
                <div className="feature-icon">
                  <Mic size={18} />
                </div>
                <div className="feature-info">
                  <h4>Audio Monitoring</h4>
                  <p>Listening for distress signals</p>
                </div>
                <div className="feature-status status-active">Active</div>
              </div>
              
              <div className="feature-item active">
                <div className="feature-icon">
                  <MapPin size={18} />
                </div>
                <div className="feature-info">
                  <h4>Location Tracking</h4>
                  <p>Real-time GPS monitoring</p>
                </div>
                <div className="feature-status status-active">Active</div>
              </div>
              
              <div className="feature-item">
                <div className="feature-icon">
                  <Camera size={18} />
                </div>
                <div className="feature-info">
                  <h4>Fake Call Recording</h4>
                  <p>Ready to activate</p>
                </div>
                <div className="feature-status status-standby">Standby</div>
              </div>
              
              <div className="feature-item active">
                <div className="feature-icon">
                  <Phone size={18} />
                </div>
                <div className="feature-info">
                  <h4>SOS Alert System</h4>
                  <p>One-tap emergency alert</p>
                </div>
                <div className="feature-status status-active">Active</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Check-in Timer */}
      <div className="card checkin-card">
        <div className="checkin-header">
          <div className="checkin-icon">
            <Clock size={24} />
          </div>
          <div>
            <h3>Safety Check-in Timer</h3>
            <p>Auto-alert if you don't check in within the set time</p>
          </div>
        </div>
        <div className="checkin-timer">
          <div className="timer-display">
            <span className="timer-value">2:45:30</span>
            <span className="timer-label">Time Remaining</span>
          </div>
          <div className="timer-actions">
            <button className="btn btn-success">Check In Now</button>
            <button className="btn btn-secondary">Extend Timer</button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
