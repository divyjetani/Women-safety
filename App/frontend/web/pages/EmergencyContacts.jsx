import React, { useState } from 'react';
import { Users, Plus, Trash2, Phone, Mail, Edit2, Shield } from 'lucide-react';
import './EmergencyContacts.css';

const EmergencyContacts = () => {
  const [contacts, setContacts] = useState([
    { id: 1, name: 'Mom', phone: '+1 (234) 567-8900', email: 'mom@email.com', role: 'Primary Guardian', avatar: '👩' },
    { id: 2, name: 'Dad', phone: '+1 (234) 567-8901', email: 'dad@email.com', role: 'Primary Guardian', avatar: '👨' },
    { id: 3, name: 'Sarah (Best Friend)', phone: '+1 (234) 567-8902', email: 'sarah@email.com', role: 'Emergency Contact', avatar: '👧' },
  ]);

  const [showAddModal, setShowAddModal] = useState(false);
  const [newContact, setNewContact] = useState({ name: '', phone: '', email: '', role: 'Emergency Contact' });

  const addContact = () => {
    // API call: await fetch('/api/guardians/add', { method: 'POST', body: JSON.stringify(newContact) })
    setContacts([...contacts, { ...newContact, id: Date.now(), avatar: '👤' }]);
    setNewContact({ name: '', phone: '', email: '', role: 'Emergency Contact' });
    setShowAddModal(false);
  };

  const deleteContact = (id) => {
    // API call: await fetch(`/api/guardians/${id}`, { method: 'DELETE' })
    setContacts(contacts.filter(c => c.id !== id));
  };

  return (
    <div className="contacts-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Emergency Contacts</h1>
          <p className="page-subtitle">Manage your trusted guardians and emergency contacts</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
          <Plus size={18} />
          Add Contact
        </button>
      </div>

      {/* Quick Emergency Numbers */}
      <div className="card emergency-numbers-card">
        <h3>Quick Emergency Numbers</h3>
        <div className="emergency-numbers-grid">
          <div className="emergency-number">
            <Phone size={24} />
            <div>
              <h4>Police</h4>
              <a href="tel:911">911</a>
            </div>
          </div>
          <div className="emergency-number">
            <Phone size={24} />
            <div>
              <h4>Ambulance</h4>
              <a href="tel:911">911</a>
            </div>
          </div>
          <div className="emergency-number">
            <Phone size={24} />
            <div>
              <h4>Women Helpline</h4>
              <a href="tel:1091">1091</a>
            </div>
          </div>
        </div>
      </div>

      {/* Contacts List */}
      <div className="contacts-grid">
        {contacts.map((contact, index) => (
          <div 
            key={contact.id} 
            className="card contact-card"
            style={{ animationDelay: `${index * 0.1}s` }}
          >
            <div className="contact-header">
              <div className="contact-avatar">{contact.avatar}</div>
              <div className="contact-actions">
                <button className="icon-btn">
                  <Edit2 size={16} />
                </button>
                <button className="icon-btn delete-btn" onClick={() => deleteContact(contact.id)}>
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
            
            <div className="contact-info">
              <h3>{contact.name}</h3>
              <span className="contact-role">{contact.role}</span>
            </div>
            
            <div className="contact-details">
              <div className="detail-item">
                <Phone size={16} />
                <a href={`tel:${contact.phone}`}>{contact.phone}</a>
              </div>
              <div className="detail-item">
                <Mail size={16} />
                <a href={`mailto:${contact.email}`}>{contact.email}</a>
              </div>
            </div>
            
            <button className="btn btn-secondary contact-alert-btn">
              <Shield size={16} />
              Send Alert
            </button>
          </div>
        ))}
      </div>

      {/* Add Contact Modal */}
      {showAddModal && (
        <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Add Emergency Contact</h2>
              <button className="close-btn" onClick={() => setShowAddModal(false)}>×</button>
            </div>
            
            <div className="modal-body">
              <div className="form-field">
                <label>Name</label>
                <input
                  type="text"
                  placeholder="Enter contact name"
                  value={newContact.name}
                  onChange={(e) => setNewContact({ ...newContact, name: e.target.value })}
                />
              </div>
              
              <div className="form-field">
                <label>Phone Number</label>
                <input
                  type="tel"
                  placeholder="+1 (234) 567-8900"
                  value={newContact.phone}
                  onChange={(e) => setNewContact({ ...newContact, phone: e.target.value })}
                />
              </div>
              
              <div className="form-field">
                <label>Email</label>
                <input
                  type="email"
                  placeholder="email@example.com"
                  value={newContact.email}
                  onChange={(e) => setNewContact({ ...newContact, email: e.target.value })}
                />
              </div>
              
              <div className="form-field">
                <label>Role</label>
                <select
                  value={newContact.role}
                  onChange={(e) => setNewContact({ ...newContact, role: e.target.value })}
                >
                  <option>Primary Guardian</option>
                  <option>Emergency Contact</option>
                  <option>Family Member</option>
                  <option>Friend</option>
                </select>
              </div>
            </div>
            
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowAddModal(false)}>
                Cancel
              </button>
              <button 
                className="btn btn-primary" 
                onClick={addContact}
                disabled={!newContact.name || !newContact.phone}
              >
                Add Contact
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default EmergencyContacts;
