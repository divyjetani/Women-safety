import React, { useState, useEffect } from 'react';
import { MapPin, Users, Navigation, Share2 } from 'lucide-react';
import './LiveTracking.css';

const LiveTracking = () => {
  const [isSharing, setIsSharing] = useState(true);
  const [guardians, setGuardians] = useState([
    { id: 1, name: 'Mom', status: 'viewing', avatar: '👩' },
    { id: 2, name: 'Sarah', status: 'viewing', avatar: '👧' },
    { id: 3, name: 'Dad', status: 'offline', avatar: '👨' }
  ]);

  const toggleSharing = async () => {
    setIsSharing(!isSharing);
    // API call: await fetch('/api/location/toggle', { method: 'POST' })
  };

  return (
    <div className="tracking-page">
      <div className="page-header">
        <h1 className="page-title">Live Location Tracking</h1>
        <p className="page-subtitle">Real-time GPS monitoring with your guardians</p>
      </div>

      <div className="tracking-controls card">
        <div className="control-item">
          <div className="control-label">
            <MapPin size={20} />
            <span>Location Sharing</span>
          </div>
          <button 
            className={`toggle-btn ${isSharing ? 'active' : ''}`}
            onClick={toggleSharing}
          >
            <span className="toggle-slider"></span>
          </button>
        </div>

        <div className="control-info">
          <p>
            {isSharing 
              ? '✅ Your location is being shared with trusted guardians' 
              : '⚠️ Location sharing is currently disabled'}
          </p>
        </div>
      </div>

      {/* Map Placeholder */}
      <div className="map-container card">
        <div className="map-placeholder">
          <MapPin size={48} />
          <h3>Map Integration</h3>
          <p>Integrate Google Maps or Mapbox here</p>
          <code>
            {`// Example Google Maps integration
import { GoogleMap, Marker } from '@react-google-maps/api';

<GoogleMap
  center={currentLocation}
  zoom={15}
>
  <Marker position={currentLocation} />
</GoogleMap>`}
          </code>
        </div>
      </div>

      {/* Active Guardians */}
      <div className="guardians-list card">
        <div className="card-header">
          <h3>Active Guardians</h3>
          <Users size={20} />
        </div>

        <div className="guardians-grid">
          {guardians.map((guardian) => (
            <div key={guardian.id} className="guardian-card">
              <div className="guardian-avatar">{guardian.avatar}</div>
              <div className="guardian-info">
                <h4>{guardian.name}</h4>
                <span className={`guardian-status status-${guardian.status}`}>
                  {guardian.status === 'viewing' ? '👁️ Viewing' : '⚫ Offline'}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default LiveTracking;
