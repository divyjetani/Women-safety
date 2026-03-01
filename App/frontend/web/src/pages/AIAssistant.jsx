import React, { useState, useRef, useEffect } from 'react';
import { Sparkles, Send, User, Bot } from 'lucide-react';
import './AIAssistant.css';

const AIAssistant = () => {
  const [messages, setMessages] = useState([
    {
      id: 1,
      type: 'bot',
      text: "Hello! I'm your AI safety assistant. I can help you with safety tips, emergency procedures, route planning, and answer any questions about staying safe. How can I assist you today?",
      timestamp: new Date()
    }
  ]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const quickQuestions = [
    "What should I do in an emergency?",
    "How can I improve my safety score?",
    "Tips for walking alone at night",
    "Explain the fake call feature"
  ];

  const sendMessage = async () => {
    if (!input.trim()) return;

    const userMessage = {
      id: messages.length + 1,
      type: 'user',
      text: input,
      timestamp: new Date()
    };

    setMessages([...messages, userMessage]);
    setInput('');
    setIsTyping(true);

    // Simulate AI response
    // In production, replace with actual AI API call
    // const response = await fetch('/api/ai/chat', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({ message: input })
    // });
    // const data = await response.json();

    setTimeout(() => {
      const botMessage = {
        id: messages.length + 2,
        type: 'bot',
        text: generateResponse(input),
        timestamp: new Date()
      };
      setMessages(prev => [...prev, botMessage]);
      setIsTyping(false);
    }, 1500);
  };

  const generateResponse = (query) => {
    // Simple response logic - replace with actual AI
    const responses = {
      emergency: "In an emergency, press and hold the red SOS button for 3 seconds. This will immediately alert your guardians and emergency services with your location. You can also shake your phone vigorously or use voice command 'Emergency Help'.",
      safety: "To improve your safety score: 1) Stay in well-lit, populated areas 2) Check in regularly 3) Share your location with trusted guardians 4) Avoid high-risk zones shown on the incident map 5) Use safe routes feature for navigation.",
      night: "When walking alone at night: 1) Use the safe route planner 2) Keep your phone charged 3) Stay in well-lit areas 4) Keep guardians informed 5) Trust your instincts 6) Have the emergency button ready 7) Stay alert and avoid distractions.",
      fake: "The fake call feature simulates an incoming call to help you exit uncomfortable situations. When activated, your phone will ring with a realistic call screen while secretly recording video and audio for evidence."
    };

    if (query.toLowerCase().includes('emergency')) return responses.emergency;
    if (query.toLowerCase().includes('safety score')) return responses.safety;
    if (query.toLowerCase().includes('night') || query.toLowerCase().includes('alone')) return responses.night;
    if (query.toLowerCase().includes('fake call')) return responses.fake;

    return "I'm here to help with your safety concerns. You can ask me about emergency procedures, safety tips, app features, or any other safety-related questions.";
  };

  const handleQuickQuestion = (question) => {
    setInput(question);
  };

  return (
    <div className="ai-assistant-page">
      <div className="page-header">
        <h1 className="page-title">AI Safety Assistant</h1>
        <p className="page-subtitle">Get instant help and safety guidance powered by AI</p>
      </div>

      <div className="chat-container card">
        <div className="chat-messages">
          {messages.map((message, index) => (
            <div 
              key={message.id} 
              className={`message message-${message.type}`}
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <div className="message-avatar">
                {message.type === 'bot' ? <Bot size={20} /> : <User size={20} />}
              </div>
              <div className="message-content">
                <p>{message.text}</p>
                <span className="message-time">
                  {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
            </div>
          ))}
          
          {isTyping && (
            <div className="message message-bot typing-indicator">
              <div className="message-avatar">
                <Bot size={20} />
              </div>
              <div className="typing-dots">
                <span></span>
                <span></span>
                <span></span>
              </div>
            </div>
          )}
          
          <div ref={messagesEndRef} />
        </div>

        {messages.length === 1 && (
          <div className="quick-questions">
            <p>Quick questions:</p>
            <div className="quick-questions-grid">
              {quickQuestions.map((question, index) => (
                <button
                  key={index}
                  className="quick-question-btn"
                  onClick={() => handleQuickQuestion(question)}
                >
                  {question}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="chat-input-container">
          <input
            type="text"
            placeholder="Ask me anything about safety..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
            className="chat-input"
          />
          <button 
            className="btn btn-primary send-btn"
            onClick={sendMessage}
            disabled={!input.trim()}
          >
            <Send size={18} />
          </button>
        </div>
      </div>
    </div>
  );
};

export default AIAssistant;
