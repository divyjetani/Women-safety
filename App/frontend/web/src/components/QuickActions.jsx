import React from 'react';
import { Phone, Camera, MapPin, Users, Mic, Route, Shield, Volume2 } from 'lucide-react';
import './QuickActions.css';

const QuickActions = () => {
  const actions = [
    {
      id: 'fake-call',
      icon: Phone,
      label: 'Fake Call',
      description: 'Simulates incoming call with recording',
      color: 'primary',
      action: () => {
        // API call: await fetch('/api/features/fake-call/activate', { method: 'POST' })
        console.log('Fake call activated');
      }
    },
    {
      id: 'location-share',
      icon: MapPin,
      label: 'Share Location',
      description: 'Send location to guardians',
      color: 'success',
      action: () => {
        // API call: await fetch('/api/location/share', { method: 'POST' })
        console.log('Location shared');
      }
    },
    {
      id: 'safe-route',
      icon: Route,
      label: 'Safe Route',
      description: 'Find safest path to destination',
      color: 'info',
      action: () => {
        // Navigate to safe routes page or trigger route calculation
        console.log('Safe route requested');
      }
    },
    {
      id: 'guardian-alert',
      icon: Users,
      label: 'Alert Guardians',
      description: 'Notify all trusted contacts',
      color: 'warning',
      action: () => {
        // API call: await fetch('/api/guardians/alert', { method: 'POST' })
        console.log('Guardians alerted');
      }
    },
    {
      id: 'audio-monitor',
      icon: Mic,
      label: 'Audio Monitor',
      description: 'Start background listening',
      color: 'purple',
      action: () => {
        // API call: await fetch('/api/audio/monitor/toggle', { method: 'POST' })
        console.log('Audio monitoring toggled');
      }
    },
    {
      id: 'voice-sos',
      icon: Volume2,
      label: 'Voice SOS',
      description: 'Activate voice command',
      color: 'teal',
      action: () => {
        // API call: await fetch('/api/voice/sos/activate', { method: 'POST' })
        console.log('Voice SOS activated');
      }
    }
  ];

  return (
    <div className="card quick-actions-card">
      <div className="card-header">
        <h3>Quick Actions</h3>
        <Shield size={20} />
      </div>
      
      <div className="quick-actions-grid">
        {actions.map((action, index) => (
          <button
            key={action.id}
            className={`quick-action-btn action-${action.color}`}
            onClick={action.action}
            style={{ animationDelay: `${index * 0.05}s` }}
          >
            <div className="action-icon-wrapper">
              <action.icon size={24} />
            </div>
            <div className="action-content">
              <h4>{action.label}</h4>
              <p>{action.description}</p>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
};

export default QuickActions;
