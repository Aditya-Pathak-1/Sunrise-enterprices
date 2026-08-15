import React, { useState } from 'react';
import {
  LayoutDashboard, Users, Factory, FileText, Package,
  Settings, Wrench, BarChart2, Zap, Bell,
  TrendingUp, TrendingDown, Sun, Fingerprint, Plus, UserPlus, AlertTriangle, Upload, User, LogOut, CheckCircle2
} from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import './App.css';

const productionData = [
  { time: '00', value: 3000 },
  { time: '04', value: 5000 },
  { time: '08', value: 4500 },
  { time: '12', value: 8000 },
  { time: '16', value: 12450 },
  { time: '20', value: 10000 },
  { time: '24', value: 11000 },
];

const ADMINS = {
  'rashmi naik': 'sunrise@123',
  'shilpa Bhoir': 'sunrise@123',
  'ayush': 'sunrise@123',
  'Ahana': 'sunrise@123',
  'aditya': 'sunrise@123',
};

function App() {
  const [view, setView] = useState<'login' | 'dashboard' | 'add_employee'>('login');
  const [currentUser, setCurrentUser] = useState('');

  // Login State
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (ADMINS[username as keyof typeof ADMINS] === password) {
      setCurrentUser(username);
      setView('dashboard');
      setLoginError('');
    } else {
      setLoginError('Invalid admin credentials.');
    }
  };

  const renderLogin = () => (
    <div style={{ display: 'flex', height: '100vh', alignItems: 'center', justifyContent: 'center', backgroundColor: '#F4F6F9' }}>
      <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '24px', width: '100%', maxWidth: '400px', boxShadow: '0 8px 24px rgba(0,0,0,0.05)' }}>
        <div className="brand" style={{ marginBottom: '32px' }}>
          <Sun size={64} color="#FF8F00" strokeWidth={2.5} />
          <div className="brand-title" style={{ fontSize: '24px' }}>SUNRISE</div>
          <div className="brand-subtitle">ADMIN PORTAL</div>
        </div>
        <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {loginError && <div style={{ color: '#F44336', fontSize: '14px', textAlign: 'center' }}>{loginError}</div>}
          <input
            type="text"
            placeholder="Admin Username (e.g., ayush)"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            style={{ padding: '16px', borderRadius: '12px', border: '1px solid #E0E0E0', fontSize: '16px', outline: 'none' }}
          />
          <input
            type="password"
            placeholder="Password (e.g., sunrise@123)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={{ padding: '16px', borderRadius: '12px', border: '1px solid #E0E0E0', fontSize: '16px', outline: 'none' }}
          />
          <button type="submit" style={{ padding: '16px', borderRadius: '12px', backgroundColor: '#FF8F00', color: 'white', border: 'none', fontSize: '16px', fontWeight: 'bold', cursor: 'pointer', marginTop: '8px' }}>
            Login to Dashboard
          </button>
        </form>
      </div>
    </div>
  );

  const renderDashboardContent = () => {
    if (view === 'add_employee') {
      return <AddEmployeeView />;
    }
    
    // Default Dashboard view
    return (
      <div className="dashboard-container">
        {/* Top Stats */}
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-icon"><Factory size={24} /></div>
            <div className="stat-title">Factory Health</div>
            <div className="stat-value">97<span className="stat-value-sub">%</span></div>
            <div className="stat-trend trend-neutral">All systems operational</div>
          </div>
          <div className="stat-card">
            <div className="stat-icon"><Settings size={24} /></div>
            <div className="stat-title">Running Machines</div>
            <div className="stat-value">24<span className="stat-value-sub">/ 25</span></div>
            <div className="stat-trend trend-up"><TrendingUp size={14}/> 2 from yesterday</div>
          </div>
          <div className="stat-card">
            <div className="stat-icon"><Users size={24} /></div>
            <div className="stat-title">Employees Present</div>
            <div className="stat-value">112</div>
            <div className="stat-trend trend-up"><TrendingUp size={14}/> 8 from yesterday</div>
          </div>
          <div className="stat-card">
            <div className="stat-icon"><FileText size={24} /></div>
            <div className="stat-title">Active Orders</div>
            <div className="stat-value">8</div>
            <div className="stat-trend trend-down">2 delayed</div>
          </div>
          <div className="stat-card">
            <div className="stat-icon"><BarChart2 size={24} /></div>
            <div className="stat-title">Today's Output</div>
            <div className="stat-value">12,450</div>
            <div className="stat-trend trend-up"><TrendingUp size={14}/> 18%</div>
          </div>
        </div>

        {/* Middle Row */}
        <div className="middle-grid">
          {/* Production Chart */}
          <div className="card-base">
            <div className="card-header">
              <div className="card-title">Today's Production</div>
              <a href="#" className="card-link">Today ⌄</a>
            </div>
            <div style={{ height: '240px', marginTop: '20px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={productionData}>
                  <defs>
                    <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#FF9800" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#FF9800" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="time" axisLine={false} tickLine={false} tick={{fill: '#9094A6', fontSize: 12}} dy={10} />
                  <YAxis axisLine={false} tickLine={false} tick={{fill: '#9094A6', fontSize: 12}} dx={-10} tickFormatter={(val) => `${val/1000}k`} />
                  <Tooltip />
                  <Area type="monotone" dataKey="value" stroke="#FF9800" strokeWidth={3} fillOpacity={1} fill="url(#colorValue)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Machine Status */}
          <div className="card-base">
            <div className="card-header">
              <div className="card-title">Machine Status</div>
              <a href="#" className="card-link card-link-orange">View All</a>
            </div>
            <div>
              {[
                { name: 'CNC-01', status: 'Running', type: 'running' },
                { name: 'Hydraulic Press', status: 'Running', type: 'running' },
                { name: 'Laser Cutter', status: 'Idle', type: 'idle' },
                { name: 'Welding Unit', status: 'Maintenance', type: 'maintenance' },
                { name: 'Paint Booth', status: 'Running', type: 'running' },
              ].map((m, i) => (
                <div className="list-item" key={i}>
                  <div className="list-item-left">
                    <div className="list-icon-bg"><Settings size={18}/></div>
                    <div className="list-item-name">{m.name}</div>
                  </div>
                  <div className={`status-badge status-${m.type}`}>
                    <div className="status-dot"></div> {m.status}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* AI Insights */}
          <div className="card-base">
            <div className="card-header">
              <div className="card-title" style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
                <Zap size={20} color="#FF9800"/> AI Insights
              </div>
            </div>
            <div>
              <div className="insight-item">
                <div className="insight-icon warning"><AlertTriangle size={18}/></div>
                <div>
                  <div className="insight-text">2 orders are likely to be delayed based on current progress.</div>
                  <a href="#" className="card-link card-link-orange">View Orders {'>'}</a>
                </div>
              </div>
              <div className="insight-item">
                <div className="insight-icon info"><Package size={18}/></div>
                <div>
                  <div className="insight-text">Raw material stock for Item X is low.</div>
                  <a href="#" className="card-link card-link-orange">Restock Now {'>'}</a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  if (view === 'login') return renderLogin();

  return (
    <div className="app-container">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="brand">
          <Sun size={48} color="#FF8F00" strokeWidth={2.5} />
          <div className="brand-title">SUNRISE</div>
          <div className="brand-subtitle">EQUIPMENTS</div>
        </div>
        
        <nav className="nav-menu">
          <a href="#" className={`nav-item ${view === 'dashboard' ? 'active' : ''}`} onClick={() => setView('dashboard')}>
            <LayoutDashboard size={20} /> Dashboard
          </a>
          <a href="#" className="nav-item"><Users size={20} /> Attendance</a>
          <a href="#" className="nav-item"><Factory size={20} /> Machines</a>
          <a href="#" className={`nav-item ${view === 'add_employee' ? 'active' : ''}`} onClick={() => setView('add_employee')}>
            <UserPlus size={20} /> Add Employee
          </a>
        </nav>

        <div style={{ flex: 1 }}></div>
        <nav className="nav-menu">
          <a href="#" className="nav-item" onClick={() => setView('login')}><LogOut size={20} /> Logout</a>
        </nav>
      </aside>

      {/* Main Content */}
      <main className="main-content">
        <div className="header-bg-decoration"></div>
        
        <header className="header">
          <div>
            <h1 className="greeting-title">Welcome, Admin {currentUser} <span style={{fontSize: '32px'}}>👋</span></h1>
            <p className="greeting-subtitle">Here's what's happening at Sunrise Equipments today.</p>
          </div>
          <div className="header-actions">
            <button className="icon-button"><Bell size={20} /></button>
            <div className="profile-avatar" style={{backgroundColor: '#FF8F00', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontWeight: 'bold'}}>
              {currentUser.charAt(0).toUpperCase()}
            </div>
          </div>
        </header>

        {renderDashboardContent()}
      </main>
    </div>
  );
}

const AddEmployeeView = () => {
  const [empId, setEmpId] = useState('');
  const [name, setName] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState('');

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0]);
      setPreview(URL.createObjectURL(e.target.files[0]));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!empId || !name || !file) return;

    setStatus('loading');
    const formData = new FormData();
    formData.append('employee_id', empId);
    formData.append('name', name);
    formData.append('file', file);

    try {
      const res = await fetch('http://localhost:8000/register', {
        method: 'POST',
        body: formData,
      });
      
      const data = await res.json();
      
      if (res.ok) {
        setStatus('success');
        setMessage(`Successfully registered ${name}!`);
        // Reset form
        setEmpId('');
        setName('');
        setFile(null);
        setPreview(null);
      } else {
        setStatus('error');
        setMessage(data.detail || 'Failed to register employee');
      }
    } catch (err) {
      setStatus('error');
      setMessage('Network error. Ensure backend is running.');
    }
  };

  return (
    <div className="dashboard-container">
      <div className="card-base" style={{ maxWidth: '600px', margin: '0 auto' }}>
        <div className="card-header" style={{ borderBottom: '1px solid #eee', paddingBottom: '20px', marginBottom: '24px' }}>
          <div className="card-title" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ backgroundColor: 'rgba(255, 143, 0, 0.1)', padding: '10px', borderRadius: '12px', color: '#FF8F00' }}>
              <UserPlus size={24} />
            </div>
            Register New Employee
          </div>
        </div>
        
        {status === 'success' && (
          <div style={{ backgroundColor: '#E8F5E9', color: '#2E7D32', padding: '16px', borderRadius: '12px', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <CheckCircle2 size={20} /> {message}
          </div>
        )}
        
        {status === 'error' && (
          <div style={{ backgroundColor: '#FFEBEE', color: '#C62828', padding: '16px', borderRadius: '12px', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertTriangle size={20} /> {message}
          </div>
        )}

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          <div style={{ display: 'flex', gap: '20px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 600, fontSize: '14px', color: '#2D3142' }}>Employee ID</label>
              <input
                type="text"
                placeholder="e.g. EMP001"
                value={empId}
                onChange={(e) => setEmpId(e.target.value.toUpperCase())}
                required
                style={{ width: '100%', padding: '14px', borderRadius: '12px', border: '1px solid #E0E0E0', fontSize: '15px', outline: 'none' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 600, fontSize: '14px', color: '#2D3142' }}>Full Name</label>
              <input
                type="text"
                placeholder="e.g. Rahul Sharma"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                style={{ width: '100%', padding: '14px', borderRadius: '12px', border: '1px solid #E0E0E0', fontSize: '15px', outline: 'none' }}
              />
            </div>
          </div>

          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 600, fontSize: '14px', color: '#2D3142' }}>Face Photo (Clear, front-facing)</label>
            <div 
              style={{ 
                border: '2px dashed #E0E0E0', 
                borderRadius: '16px', 
                padding: '32px', 
                textAlign: 'center',
                backgroundColor: '#F8F9FB',
                position: 'relative',
                cursor: 'pointer'
              }}
            >
              <input 
                type="file" 
                accept="image/*" 
                onChange={handleFileChange}
                required
                style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', opacity: 0, cursor: 'pointer' }}
              />
              {preview ? (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
                  <img src={preview} alt="Preview" style={{ width: '120px', height: '120px', borderRadius: '50%', objectFit: 'cover', border: '4px solid white', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }} />
                  <span style={{ color: '#FF8F00', fontWeight: 600, fontSize: '14px' }}>Change Photo</span>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', color: '#9094A6' }}>
                  <div style={{ width: '48px', height: '48px', borderRadius: '50%', backgroundColor: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
                    <Upload size={24} color="#FF8F00" />
                  </div>
                  <span>Click or drag photo to upload</span>
                </div>
              )}
            </div>
          </div>

          <button 
            type="submit" 
            disabled={status === 'loading'}
            style={{ 
              padding: '16px', 
              borderRadius: '12px', 
              backgroundColor: status === 'loading' ? '#FFCC80' : '#FF8F00', 
              color: 'white', 
              border: 'none', 
              fontSize: '16px', 
              fontWeight: 'bold', 
              cursor: status === 'loading' ? 'not-allowed' : 'pointer',
              marginTop: '8px',
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            {status === 'loading' ? 'Registering...' : (
              <><User size={20} /> Register Employee</>
            )}
          </button>
        </form>
      </div>
    </div>
  );
};

export default App;
