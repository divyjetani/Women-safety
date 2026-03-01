import React from 'react';
import { BarChart3, TrendingUp, Clock, MapPin, AlertTriangle, Users } from 'lucide-react';
import './Analytics.css';

const Analytics = () => {
  const weeklyData = [
    { day: 'Mon', incidents: 5, alerts: 2, checkIns: 12 },
    { day: 'Tue', incidents: 3, alerts: 1, checkIns: 15 },
    { day: 'Wed', incidents: 7, alerts: 3, checkIns: 10 },
    { day: 'Thu', incidents: 4, alerts: 1, checkIns: 14 },
    { day: 'Fri', incidents: 6, alerts: 2, checkIns: 11 },
    { day: 'Sat', incidents: 2, alerts: 0, checkIns: 18 },
    { day: 'Sun', incidents: 3, alerts: 1, checkIns: 16 },
  ];

  const topLocations = [
    { name: 'Home', visits: 45, safetyScore: 98 },
    { name: 'Office', visits: 38, safetyScore: 92 },
    { name: 'Gym', visits: 22, safetyScore: 88 },
    { name: 'Mall', visits: 15, safetyScore: 85 },
  ];

  return (
    <div className="analytics-page">
      <div className="page-header">
        <h1 className="page-title">Safety Analytics</h1>
        <p className="page-subtitle">Insights and patterns from your safety data</p>
      </div>

      {/* Overview Cards */}
      <div className="analytics-grid">
        <div className="card analytics-card">
          <div className="analytics-card-header">
            <h3>Weekly Activity</h3>
            <BarChart3 size={20} />
          </div>
          
          <div className="chart-container">
            <div className="bar-chart">
              {weeklyData.map((data, index) => (
                <div key={index} className="bar-group">
                  <div className="bars">
                    <div 
                      className="bar bar-incidents" 
                      style={{ height: `${(data.incidents / 10) * 100}%` }}
                      title={`${data.incidents} incidents`}
                    ></div>
                    <div 
                      className="bar bar-alerts" 
                      style={{ height: `${(data.alerts / 10) * 100}%` }}
                      title={`${data.alerts} alerts`}
                    ></div>
                    <div 
                      className="bar bar-checkins" 
                      style={{ height: `${(data.checkIns / 20) * 100}%` }}
                      title={`${data.checkIns} check-ins`}
                    ></div>
                  </div>
                  <span className="bar-label">{data.day}</span>
                </div>
              ))}
            </div>
            
            <div className="chart-legend">
              <div className="legend-item">
                <span className="legend-color" style={{ background: 'var(--danger-red)' }}></span>
                Incidents
              </div>
              <div className="legend-item">
                <span className="legend-color" style={{ background: 'var(--warning-amber)' }}></span>
                Alerts
              </div>
              <div className="legend-item">
                <span className="legend-color" style={{ background: 'var(--safe-green)' }}></span>
                Check-ins
              </div>
            </div>
          </div>
        </div>

        <div className="card analytics-card">
          <div className="analytics-card-header">
            <h3>Top Locations</h3>
            <MapPin size={20} />
          </div>
          
          <div className="locations-list">
            {topLocations.map((location, index) => (
              <div key={index} className="location-item">
                <div className="location-info">
                  <h4>{location.name}</h4>
                  <span>{location.visits} visits</span>
                </div>
                <div className="location-score">
                  <div className="score-bar">
                    <div 
                      className="score-fill" 
                      style={{ width: `${location.safetyScore}%` }}
                    ></div>
                  </div>
                  <span className="score-value">{location.safetyScore}%</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Additional Metrics */}
      <div className="metrics-grid">
        <div className="card metric-card">
          <Clock size={32} />
          <h3>Peak Hours</h3>
          <p className="metric-value">6 PM - 9 PM</p>
          <p className="metric-desc">Most active time for alerts</p>
        </div>

        <div className="card metric-card">
          <Users size={32} />
          <h3>Guardian Engagement</h3>
          <p className="metric-value">94%</p>
          <p className="metric-desc">Average response rate</p>
        </div>

        <div className="card metric-card">
          <AlertTriangle size={32} />
          <h3>Risk Areas</h3>
          <p className="metric-value">3 Zones</p>
          <p className="metric-desc">Require attention</p>
        </div>

        <div className="card metric-card">
          <TrendingUp size={32} />
          <h3>Safety Trend</h3>
          <p className="metric-value">+12%</p>
          <p className="metric-desc">Improvement this month</p>
        </div>
      </div>
    </div>
  );
};

export default Analytics;
