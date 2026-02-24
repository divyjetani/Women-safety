import React, { useState } from 'react';
import { Route, MapPin, Navigation, TrendingUp, AlertTriangle, Clock } from 'lucide-react';
import './SafeRoutes.css';

const SafeRoutes = () => {
  const [origin, setOrigin] = useState('');
  const [destination, setDestination] = useState('');
  const [routes, setRoutes] = useState([]);
  const [calculating, setCalculating] = useState(false);

  const calculateRoutes = async () => {
    setCalculating(true);
    
    // API call placeholder
    // const response = await fetch('/api/analytics/safe-route', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({ origin, destination })
    // });
    // const data = await response.json();
    
    // Mock data
    setTimeout(() => {
      setRoutes([
        {
          id: 1,
          name: 'Safest Route',
          distance: '5.2 km',
          duration: '15 min',
          safetyScore: 95,
          highlights: ['Well-lit streets', 'Police stations nearby', 'High foot traffic'],
          type: 'safest'
        },
        {
          id: 2,
          name: 'Fastest Route',
          distance: '4.1 km',
          duration: '10 min',
          safetyScore: 78,
          highlights: ['Main roads', 'CCTV coverage', 'Moderate lighting'],
          type: 'fastest'
        },
        {
          id: 3,
          name: 'Balanced Route',
          distance: '4.8 km',
          duration: '13 min',
          safetyScore: 88,
          highlights: ['Safe neighborhoods', 'Good lighting', 'Emergency services'],
          type: 'balanced'
        }
      ]);
      setCalculating(false);
    }, 1500);
  };

  return (
    <div className="safe-routes-page">
      <div className="page-header">
        <h1 className="page-title">Safe Route Planning</h1>
        <p className="page-subtitle">AI-powered route suggestions based on safety analytics</p>
      </div>

      {/* Route Input */}
      <div className="card route-input-card">
        <div className="input-group">
          <div className="input-field">
            <MapPin size={20} />
            <input
              type="text"
              placeholder="Enter starting location"
              value={origin}
              onChange={(e) => setOrigin(e.target.value)}
            />
          </div>
          
          <div className="input-field">
            <Navigation size={20} />
            <input
              type="text"
              placeholder="Enter destination"
              value={destination}
              onChange={(e) => setDestination(e.target.value)}
            />
          </div>
          
          <button 
            className="btn btn-primary calculate-btn"
            onClick={calculateRoutes}
            disabled={!origin || !destination || calculating}
          >
            {calculating ? 'Calculating...' : 'Find Safe Routes'}
            <Route size={18} />
          </button>
        </div>
      </div>

      {/* Routes List */}
      {routes.length > 0 && (
        <div className="routes-container">
          {routes.map((route, index) => (
            <div 
              key={route.id} 
              className={`card route-card route-${route.type}`}
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <div className="route-header">
                <div className="route-title">
                  <h3>{route.name}</h3>
                  <span className={`route-badge badge-${route.type}`}>
                    {route.type === 'safest' && '🛡️ Recommended'}
                    {route.type === 'fastest' && '⚡ Fastest'}
                    {route.type === 'balanced' && '⚖️ Balanced'}
                  </span>
                </div>
                <div className="safety-score-mini">
                  <span className="score-value">{route.safetyScore}</span>
                  <span className="score-label">Safety Score</span>
                </div>
              </div>

              <div className="route-stats">
                <div className="stat-item">
                  <Route size={16} />
                  <span>{route.distance}</span>
                </div>
                <div className="stat-item">
                  <Clock size={16} />
                  <span>{route.duration}</span>
                </div>
              </div>

              <div className="route-highlights">
                {route.highlights.map((highlight, idx) => (
                  <span key={idx} className="highlight-tag">
                    ✓ {highlight}
                  </span>
                ))}
              </div>

              <button className="btn btn-secondary select-route-btn">
                Select This Route
                <Navigation size={16} />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Map Placeholder */}
      <div className="card map-preview-card">
        <div className="map-preview-placeholder">
          <Route size={48} />
          <h3>Route Map Preview</h3>
          <p>Integrate Google Maps or Mapbox to show route visualization</p>
          <code className="code-snippet">
{`// Google Maps Integration
import { GoogleMap, DirectionsRenderer } from '@react-google-maps/api';

<GoogleMap
  center={origin}
  zoom={12}
>
  <DirectionsRenderer 
    directions={routeDirections}
    options={{ 
      polylineOptions: { 
        strokeColor: '#00E676',
        strokeWeight: 5 
      }
    }}
  />
</GoogleMap>`}
          </code>
        </div>
      </div>
    </div>
  );
};

export default SafeRoutes;
