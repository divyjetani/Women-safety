import React from 'react';
import { AlertTriangle, MapPin, Clock, CheckCircle } from 'lucide-react';
import './RecentAlerts.css';

const RecentAlerts = () => {
  const alerts = [
    {
      id: 1,
      type: 'geofence',
      message: 'Left safe zone - Home',
      location: '123 Main St, City',
      timestamp: '2 minutes ago',
      status: 'active',
      severity: 'warning'
    },
    {
      id: 2,
      type: 'checkin',
      message: 'Check-in completed',
      location: 'Downtown Area',
      timestamp: '15 minutes ago',
      status: 'resolved',
      severity: 'success'
    },
    {
      id: 3,
      type: 'audio',
      message: 'Audio pattern detected',
      location: 'Park Street',
      timestamp: '1 hour ago',
      status: 'resolved',
      severity: 'danger'
    }
  ];

  const getIcon = (type) => {
    switch(type) {
      case 'geofence': return MapPin;
      case 'checkin': return CheckCircle;
      case 'audio': return AlertTriangle;
      default: return AlertTriangle;
    }
  };

  return (
    <div className="card recent-alerts-card">
      <div className="card-header">
        <h3>Recent Alerts</h3>
        <AlertTriangle size={20} />
      </div>

      <div className="alerts-list">
        {alerts.map((alert, index) => {
          const Icon = getIcon(alert.type);
          return (
            <div 
              key={alert.id} 
              className={`alert-item alert-${alert.severity}`}
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <div className={`alert-icon icon-${alert.severity}`}>
                <Icon size={18} />
              </div>
              <div className="alert-content">
                <h4>{alert.message}</h4>
                <div className="alert-meta">
                  <span className="alert-location">
                    <MapPin size={12} />
                    {alert.location}
                  </span>
                  <span className="alert-time">
                    <Clock size={12} />
                    {alert.timestamp}
                  </span>
                </div>
              </div>
              <span className={`alert-status status-${alert.status}`}>
                {alert.status}
              </span>
            </div>
          );
        })}
      </div>

      <button className="view-all-btn">View All Alerts</button>
    </div>
  );
};

export default RecentAlerts;
