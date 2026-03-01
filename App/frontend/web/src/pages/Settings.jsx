import React, { useState } from 'react';
import { Settings as SettingsIcon, Bell, Shield, MapPin, Volume2, Battery } from 'lucide-react';
import './Settings.css';

const Settings = () => {
  const [settings, setSettings] = useState({
    notifications: {
      emergencyAlerts: true,
      guardianUpdates: true,
      safetyTips: false,
      locationUpdates: true
    },
    privacy: {
      shareLocation: true,
      anonymousData: false,
      saveHistory: true
    },
    safety: {
      autoSOS: true,
      shakeDetection: true,
      voiceActivation: false,
      audioMonitoring: true
    },
    battery: {
      batterySaver: false,
      reducedTracking: false
    }
  });

  const toggleSetting = (category, key) => {
    setSettings(prev => ({
      ...prev,
      [category]: {
        ...prev[category],
        [key]: !prev[category][key]
      }
    }));

    // API call to save settings
    // await fetch('/api/user/settings', {
    //   method: 'PUT',
    //   body: JSON.stringify(settings)
    // });
  };

  return (
    <div className="settings-page">
      <div className="page-header">
        <h1 className="page-title">Settings</h1>
        <p className="page-subtitle">Customize your safety preferences</p>
      </div>

      <div className="settings-grid">
        {/* Notifications */}
        <div className="card settings-section">
          <div className="section-header">
            <Bell size={24} />
            <h3>Notifications</h3>
          </div>
          
          <div className="settings-list">
            <div className="setting-item">
              <div className="setting-info">
                <h4>Emergency Alerts</h4>
                <p>Critical safety notifications</p>
              </div>
              <button 
                className={`toggle-switch ${settings.notifications.emergencyAlerts ? 'active' : ''}`}
                onClick={() => toggleSetting('notifications', 'emergencyAlerts')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Guardian Updates</h4>
                <p>Notifications from your guardians</p>
              </div>
              <button 
                className={`toggle-switch ${settings.notifications.guardianUpdates ? 'active' : ''}`}
                onClick={() => toggleSetting('notifications', 'guardianUpdates')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Safety Tips</h4>
                <p>Daily safety recommendations</p>
              </div>
              <button 
                className={`toggle-switch ${settings.notifications.safetyTips ? 'active' : ''}`}
                onClick={() => toggleSetting('notifications', 'safetyTips')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>
          </div>
        </div>

        {/* Safety Features */}
        <div className="card settings-section">
          <div className="section-header">
            <Shield size={24} />
            <h3>Safety Features</h3>
          </div>
          
          <div className="settings-list">
            <div className="setting-item">
              <div className="setting-info">
                <h4>Automatic SOS</h4>
                <p>AI-powered emergency detection</p>
              </div>
              <button 
                className={`toggle-switch ${settings.safety.autoSOS ? 'active' : ''}`}
                onClick={() => toggleSetting('safety', 'autoSOS')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Shake Detection</h4>
                <p>Trigger alert by shaking phone</p>
              </div>
              <button 
                className={`toggle-switch ${settings.safety.shakeDetection ? 'active' : ''}`}
                onClick={() => toggleSetting('safety', 'shakeDetection')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Voice Activation</h4>
                <p>Voice command emergency trigger</p>
              </div>
              <button 
                className={`toggle-switch ${settings.safety.voiceActivation ? 'active' : ''}`}
                onClick={() => toggleSetting('safety', 'voiceActivation')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Audio Monitoring</h4>
                <p>Background audio analysis</p>
              </div>
              <button 
                className={`toggle-switch ${settings.safety.audioMonitoring ? 'active' : ''}`}
                onClick={() => toggleSetting('safety', 'audioMonitoring')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>
          </div>
        </div>

        {/* Privacy */}
        <div className="card settings-section">
          <div className="section-header">
            <MapPin size={24} />
            <h3>Privacy & Location</h3>
          </div>
          
          <div className="settings-list">
            <div className="setting-item">
              <div className="setting-info">
                <h4>Share Location</h4>
                <p>Allow guardians to see your location</p>
              </div>
              <button 
                className={`toggle-switch ${settings.privacy.shareLocation ? 'active' : ''}`}
                onClick={() => toggleSetting('privacy', 'shareLocation')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Anonymous Analytics</h4>
                <p>Help improve safety features</p>
              </div>
              <button 
                className={`toggle-switch ${settings.privacy.anonymousData ? 'active' : ''}`}
                onClick={() => toggleSetting('privacy', 'anonymousData')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Save Location History</h4>
                <p>Keep record of your locations</p>
              </div>
              <button 
                className={`toggle-switch ${settings.privacy.saveHistory ? 'active' : ''}`}
                onClick={() => toggleSetting('privacy', 'saveHistory')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>
          </div>
        </div>

        {/* Battery */}
        <div className="card settings-section">
          <div className="section-header">
            <Battery size={24} />
            <h3>Battery Optimization</h3>
          </div>
          
          <div className="settings-list">
            <div className="setting-item">
              <div className="setting-info">
                <h4>Battery Saver Mode</h4>
                <p>Optimize for low battery situations</p>
              </div>
              <button 
                className={`toggle-switch ${settings.battery.batterySaver ? 'active' : ''}`}
                onClick={() => toggleSetting('battery', 'batterySaver')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>

            <div className="setting-item">
              <div className="setting-info">
                <h4>Reduced Tracking</h4>
                <p>Lower GPS accuracy to save battery</p>
              </div>
              <button 
                className={`toggle-switch ${settings.battery.reducedTracking ? 'active' : ''}`}
                onClick={() => toggleSetting('battery', 'reducedTracking')}
              >
                <span className="toggle-slider"></span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;
