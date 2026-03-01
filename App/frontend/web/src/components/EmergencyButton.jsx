import React, { useState, useEffect } from 'react';
import { AlertTriangle, X } from 'lucide-react';
import './EmergencyButton.css';

const EmergencyButton = () => {
  const [isPressed, setIsPressed] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [isActivated, setIsActivated] = useState(false);

  useEffect(() => {
    let timer;
    if (isPressed && countdown > 0) {
      timer = setTimeout(() => setCountdown(countdown - 1), 1000);
    } else if (isPressed && countdown === 0) {
      triggerEmergency();
    }
    return () => clearTimeout(timer);
  }, [isPressed, countdown]);

  const handleMouseDown = () => {
    setIsPressed(true);
    setCountdown(3); // 3 second hold to prevent accidental triggers
  };

  const handleMouseUp = () => {
    if (countdown > 0) {
      setIsPressed(false);
      setCountdown(0);
    }
  };

  const triggerEmergency = () => {
    setIsActivated(true);
    
    // Dispatch emergency event
    window.dispatchEvent(new CustomEvent('emergency-triggered', { 
      detail: { emergency: true, timestamp: new Date() } 
    }));
    
    // API call placeholder
    // const sendEmergency = async () => {
    //   try {
    //     const response = await fetch('/api/emergency/trigger', {
    //       method: 'POST',
    //       headers: { 'Content-Type': 'application/json' },
    //       body: JSON.stringify({
    //         userId: 'USER_ID',
    //         location: { lat: 0, lng: 0 }, // Get from geolocation
    //         timestamp: new Date().toISOString(),
    //         type: 'manual'
    //       })
    //     });
    //     const data = await response.json();
    //     console.log('Emergency sent:', data);
    //   } catch (error) {
    //     console.error('Failed to send emergency:', error);
    //   }
    // };
    // sendEmergency();
  };

  const cancelEmergency = () => {
    setIsActivated(false);
    setIsPressed(false);
    setCountdown(0);
    
    // API call to cancel
    // fetch('/api/emergency/cancel', { method: 'POST' });
  };

  return (
    <div className="emergency-container">
      {!isActivated ? (
        <div className="emergency-button-wrapper">
          <button
            className={`emergency-button ${isPressed ? 'pressing' : ''}`}
            onMouseDown={handleMouseDown}
            onMouseUp={handleMouseUp}
            onMouseLeave={handleMouseUp}
            onTouchStart={handleMouseDown}
            onTouchEnd={handleMouseUp}
          >
            <div className="emergency-ripple"></div>
            <div className="emergency-content">
              <AlertTriangle size={48} />
              <span className="emergency-text">
                {isPressed ? `Release in ${countdown}s` : 'HOLD FOR SOS'}
              </span>
            </div>
          </button>
          <p className="emergency-hint">Hold for 3 seconds to activate emergency alert</p>
        </div>
      ) : (
        <div className="emergency-active">
          <div className="emergency-active-content">
            <div className="emergency-icon-large">
              <AlertTriangle size={64} />
            </div>
            <h2>Emergency Alert Activated</h2>
            <p>Your trusted contacts and emergency services have been notified</p>
            <div className="emergency-actions">
              <button className="btn btn-danger" onClick={cancelEmergency}>
                <X size={20} />
                Cancel Alert
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default EmergencyButton;
