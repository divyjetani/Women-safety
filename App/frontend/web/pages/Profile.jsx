import React, { useState } from 'react';
import { User, Mail, Phone, MapPin, Edit2, Save, Camera } from 'lucide-react';
import './Profile.css';

const Profile = () => {
  const [isEditing, setIsEditing] = useState(false);
  const [profile, setProfile] = useState({
    name: 'Sarah Johnson',
    email: 'sarah.johnson@email.com',
    phone: '+1 (234) 567-8900',
    address: '123 Main Street, City, State 12345',
    emergencyContact: 'Mom - +1 (234) 567-8901',
    bloodGroup: 'O+',
    medicalInfo: 'No known allergies'
  });

  const handleSave = () => {
    setIsEditing(false);
    // API call to save profile
    // await fetch('/api/user/profile', {
    //   method: 'PUT',
    //   body: JSON.stringify(profile)
    // });
  };

  const handleChange = (field, value) => {
    setProfile(prev => ({ ...prev, [field]: value }));
  };

  return (
    <div className="profile-page">
      <div className="page-header">
        <h1 className="page-title">My Profile</h1>
        <p className="page-subtitle">Manage your personal information</p>
      </div>

      <div className="profile-grid">
        {/* Profile Card */}
        <div className="card profile-card">
          <div className="profile-avatar-section">
            <div className="profile-avatar">
              <User size={48} />
            </div>
            <button className="avatar-upload-btn">
              <Camera size={16} />
              Change Photo
            </button>
          </div>

          <div className="profile-stats">
            <div className="stat">
              <h4>Safety Score</h4>
              <p className="stat-value">85%</p>
            </div>
            <div className="stat">
              <h4>Active Days</h4>
              <p className="stat-value">127</p>
            </div>
            <div className="stat">
              <h4>Guardians</h4>
              <p className="stat-value">5</p>
            </div>
          </div>
        </div>

        {/* Information Card */}
        <div className="card info-card">
          <div className="card-header">
            <h3>Personal Information</h3>
            <button 
              className={`btn ${isEditing ? 'btn-success' : 'btn-secondary'}`}
              onClick={isEditing ? handleSave : () => setIsEditing(true)}
            >
              {isEditing ? (
                <>
                  <Save size={16} />
                  Save Changes
                </>
              ) : (
                <>
                  <Edit2 size={16} />
                  Edit Profile
                </>
              )}
            </button>
          </div>

          <div className="info-fields">
            <div className="info-field">
              <label>
                <User size={18} />
                Full Name
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={profile.name}
                  onChange={(e) => handleChange('name', e.target.value)}
                />
              ) : (
                <p>{profile.name}</p>
              )}
            </div>

            <div className="info-field">
              <label>
                <Mail size={18} />
                Email Address
              </label>
              {isEditing ? (
                <input
                  type="email"
                  value={profile.email}
                  onChange={(e) => handleChange('email', e.target.value)}
                />
              ) : (
                <p>{profile.email}</p>
              )}
            </div>

            <div className="info-field">
              <label>
                <Phone size={18} />
                Phone Number
              </label>
              {isEditing ? (
                <input
                  type="tel"
                  value={profile.phone}
                  onChange={(e) => handleChange('phone', e.target.value)}
                />
              ) : (
                <p>{profile.phone}</p>
              )}
            </div>

            <div className="info-field">
              <label>
                <MapPin size={18} />
                Home Address
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={profile.address}
                  onChange={(e) => handleChange('address', e.target.value)}
                />
              ) : (
                <p>{profile.address}</p>
              )}
            </div>
          </div>
        </div>

        {/* Medical Information */}
        <div className="card medical-card">
          <div className="card-header">
            <h3>Medical Information</h3>
          </div>

          <div className="info-fields">
            <div className="info-field">
              <label>Blood Group</label>
              {isEditing ? (
                <select
                  value={profile.bloodGroup}
                  onChange={(e) => handleChange('bloodGroup', e.target.value)}
                >
                  <option>A+</option>
                  <option>A-</option>
                  <option>B+</option>
                  <option>B-</option>
                  <option>AB+</option>
                  <option>AB-</option>
                  <option>O+</option>
                  <option>O-</option>
                </select>
              ) : (
                <p>{profile.bloodGroup}</p>
              )}
            </div>

            <div className="info-field">
              <label>Medical Information</label>
              {isEditing ? (
                <textarea
                  value={profile.medicalInfo}
                  onChange={(e) => handleChange('medicalInfo', e.target.value)}
                  rows={3}
                  placeholder="Allergies, medications, conditions..."
                />
              ) : (
                <p>{profile.medicalInfo}</p>
              )}
            </div>

            <div className="info-field">
              <label>Emergency Contact</label>
              {isEditing ? (
                <input
                  type="text"
                  value={profile.emergencyContact}
                  onChange={(e) => handleChange('emergencyContact', e.target.value)}
                  placeholder="Name - Phone Number"
                />
              ) : (
                <p>{profile.emergencyContact}</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Profile;
