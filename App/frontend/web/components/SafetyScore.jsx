import React from 'react';
import { Shield, TrendingUp, MapPin, AlertTriangle } from 'lucide-react';
import './SafetyScore.css';

const SafetyScore = ({ score }) => {
  const getScoreLevel = (score) => {
    if (score >= 80) return { level: 'high', color: 'success', label: 'Very Safe' };
    if (score >= 60) return { level: 'medium', color: 'warning', label: 'Moderate' };
    return { level: 'low', color: 'danger', label: 'Caution' };
  };

  const { level, color, label } = getScoreLevel(score);

  const factors = [
    { icon: MapPin, label: 'Location', value: 'Safe Area', status: 'good' },
    { icon: Shield, label: 'Time of Day', value: 'Daytime', status: 'good' },
    { icon: AlertTriangle, label: 'Incident Reports', value: 'Low', status: 'good' },
    { icon: TrendingUp, label: 'Crowd Density', value: 'Moderate', status: 'moderate' }
  ];

  return (
    <div className="card safety-score-card">
      <div className="card-header">
        <h3>Safety Score</h3>
        <Shield size={20} />
      </div>

      <div className="score-display">
        <div className="score-circle-container">
          <svg className="score-circle" viewBox="0 0 200 200">
            <circle
              cx="100"
              cy="100"
              r="85"
              fill="none"
              stroke="var(--bg-tertiary)"
              strokeWidth="12"
            />
            <circle
              cx="100"
              cy="100"
              r="85"
              fill="none"
              stroke={`var(--${color === 'success' ? 'safe-green' : color === 'warning' ? 'warning-amber' : 'danger-red'})`}
              strokeWidth="12"
              strokeDasharray={`${(score / 100) * 534} 534`}
              strokeLinecap="round"
              transform="rotate(-90 100 100)"
              className="score-progress"
            />
          </svg>
          <div className="score-value">
            <span className="score-number">{score}</span>
            <span className="score-label">{label}</span>
          </div>
        </div>
      </div>

      <div className="safety-factors">
        <h4>Safety Factors</h4>
        <div className="factors-list">
          {factors.map((factor, index) => (
            <div key={index} className="factor-item" style={{ animationDelay: `${index * 0.1}s` }}>
              <div className="factor-icon">
                <factor.icon size={18} />
              </div>
              <div className="factor-content">
                <span className="factor-label">{factor.label}</span>
                <span className="factor-value">{factor.value}</span>
              </div>
              <span className={`factor-status status-${factor.status}`}></span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default SafetyScore;
