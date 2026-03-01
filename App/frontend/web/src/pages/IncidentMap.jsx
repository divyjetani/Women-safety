import React, { useState } from 'react';
import { Map, AlertTriangle, MapPin, Filter, TrendingUp } from 'lucide-react';
import './IncidentMap.css';

const IncidentMap = () => {
  const [filter, setFilter] = useState('all');
  const [timeRange, setTimeRange] = useState('7days');

  const incidents = [
    { id: 1, type: 'harassment', location: 'Downtown Area', severity: 'high', date: '2 days ago', count: 3 },
    { id: 2, type: 'theft', location: 'Park Street', severity: 'medium', date: '3 days ago', count: 2 },
    { id: 3, type: 'assault', location: 'City Center', severity: 'high', date: '5 days ago', count: 1 },
    { id: 4, type: 'stalking', location: 'University Campus', severity: 'medium', date: '6 days ago', count: 2 },
  ];

  const stats = [
    { label: 'Total Incidents', value: '127', trend: '-12%', color: 'success' },
    { label: 'High Severity', value: '23', trend: '-5%', color: 'danger' },
    { label: 'Safe Zones', value: '45', trend: '+8%', color: 'success' },
    { label: 'Active Reports', value: '8', trend: 'New', color: 'warning' },
  ];

  return (
    <div className="incident-map-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Incident Heatmap</h1>
          <p className="page-subtitle">Real-time visualization of reported incidents in your area</p>
        </div>
      </div>

      {/* Stats */}
      <div className="stats-row">
        {stats.map((stat, index) => (
          <div key={index} className={`stat-box stat-${stat.color}`}>
            <span className="stat-label">{stat.label}</span>
            <div className="stat-data">
              <span className="stat-value">{stat.value}</span>
              <span className={`stat-trend trend-${stat.color}`}>
                <TrendingUp size={14} />
                {stat.trend}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="card filters-card">
        <div className="filters-row">
          <div className="filter-group">
            <Filter size={18} />
            <select value={filter} onChange={(e) => setFilter(e.target.value)}>
              <option value="all">All Incidents</option>
              <option value="harassment">Harassment</option>
              <option value="theft">Theft</option>
              <option value="assault">Assault</option>
              <option value="stalking">Stalking</option>
            </select>
          </div>
          
          <div className="filter-group">
            <MapPin size={18} />
            <select value={timeRange} onChange={(e) => setTimeRange(e.target.value)}>
              <option value="24hours">Last 24 Hours</option>
              <option value="7days">Last 7 Days</option>
              <option value="30days">Last 30 Days</option>
              <option value="all">All Time</option>
            </select>
          </div>
        </div>
      </div>

      {/* Map */}
      <div className="card map-container-card">
        <div className="heatmap-placeholder">
          <Map size={64} />
          <h3>Incident Heatmap Visualization</h3>
          <p>Integrate mapping library to display incident heatmap</p>
          <code className="integration-code">
{`// Mapbox Heatmap Example
import mapboxgl from 'mapbox-gl';
import 'mapbox-gl/dist/mapbox-gl.css';

map.addLayer({
  id: 'incidents-heat',
  type: 'heatmap',
  source: 'incidents',
  paint: {
    'heatmap-weight': ['get', 'severity'],
    'heatmap-intensity': 1,
    'heatmap-color': [
      'interpolate',
      ['linear'],
      ['heatmap-density'],
      0, 'rgba(0, 230, 118, 0)',
      0.5, 'rgba(255, 179, 0, 0.5)',
      1, 'rgba(255, 23, 68, 1)'
    ],
    'heatmap-radius': 30
  }
});`}
          </code>
        </div>
      </div>

      {/* Incidents List */}
      <div className="card incidents-list-card">
        <div className="card-header">
          <h3>Recent Incidents</h3>
          <AlertTriangle size={20} />
        </div>

        <div className="incidents-list">
          {incidents.map((incident, index) => (
            <div 
              key={incident.id} 
              className={`incident-item incident-${incident.severity}`}
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <div className={`incident-marker marker-${incident.severity}`}>
                <AlertTriangle size={20} />
              </div>
              
              <div className="incident-content">
                <div className="incident-header">
                  <h4>{incident.type.charAt(0).toUpperCase() + incident.type.slice(1)}</h4>
                  <span className={`severity-badge badge-${incident.severity}`}>
                    {incident.severity}
                  </span>
                </div>
                
                <div className="incident-meta">
                  <span className="incident-location">
                    <MapPin size={14} />
                    {incident.location}
                  </span>
                  <span className="incident-date">{incident.date}</span>
                  <span className="incident-count">{incident.count} report{incident.count > 1 ? 's' : ''}</span>
                </div>
              </div>
            </div>
          ))}
        </div>

        <button className="btn btn-secondary view-all-btn">
          View All Incidents
        </button>
      </div>
    </div>
  );
};

export default IncidentMap;
