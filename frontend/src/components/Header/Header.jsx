import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { 
  FaSignOutAlt, 
  FaKey, 
  FaUser, 
  FaUsers, 
  FaFileAlt,
  FaCode,
  FaReact,
  FaPython,
  FaHeadset,
  FaChartBar,
  FaBook,
  FaUserCog,
  FaTicketAlt,
  FaListAlt,
  FaClipboardList
} from 'react-icons/fa';
import { useAuth } from '../../context/AuthContext';
import logo from '../../assets/logo_header.svg';
import './../../styles//Header.css';

function Header() {
  const [menuOpen, setMenuOpen] = useState(false);
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const toggleMenu = () => {
    setMenuOpen(!menuOpen);
  };

  return (
    <header className="app-header">
      <div className="app-header-content">
        <Link to="/welcome" className="app-logo">
          <img src={logo} alt="Logo" />
        </Link>

        <div className="hamburger" onClick={toggleMenu}>
          <span className={`bar ${menuOpen ? 'active' : ''}`}></span>
          <span className={`bar ${menuOpen ? 'active' : ''}`}></span>
          <span className={`bar ${menuOpen ? 'active' : ''}`}></span>
        </div>

        <nav className={`app-nav ${menuOpen ? 'active' : ''}`}>
          <ul className="app-menu">
            {(user?.is_staff || user?.is_gestor) && (
              <li className="app-menu-item user-menu">
                <Link to="/gestao-usuarios">
                  <FaUsers />
                  <span>Gestão de Usuários</span>
                </Link>
                <ul className="user-submenu">
                  <li>
                    <Link to="/gestao-usuarios">
                      <FaUsers />
                      <span>Gestão de Usuários</span>
                    </Link>
                  </li>
                </ul>
              </li>
            )}
            {(user?.is_staff || user?.is_gestor) && (
              <li className="app-menu-item user-menu">
                <Link to="/premissas/">
                  <FaClipboardList />
                  <span>Premissas</span>
                </Link>
              </li>
            )}
            <li className="app-menu-item user-menu">
              <Link to="/avaliacoes">
                <FaHeadset />
                <span>Avaliação de Incidentes</span>
              </Link>
              <ul className="user-submenu">
                <li>
                  <Link to="/avaliacoes">
                    <FaListAlt />
                    <span>Avaliações</span>
                  </Link>
                </li>
              </ul>
            </li>
            <li className="app-menu-item user-menu">
              <Link to="/relatorios">
                <FaChartBar />
                <span>Relatórios</span>
              </Link>
              <ul className="user-submenu">
                <li>
                  <Link to="/relatorios/tecnicos">
                    <FaUsers />
                    <span>Técnicos</span>
                  </Link>
                </li>
                <li>
                  <Link to="/relatorios/equipes">
                    <FaUserCog />
                    <span>Equipes</span>
                  </Link>
                </li>
              </ul>
            </li>
            <li className="app-menu-divider" />
            <li className="app-menu-item user-menu">
              <span className="user-name">
                <FaUser />
                <span>{`${user?.first_name || ''} ${user?.last_name || ''}`}</span>
              </span>
              <ul className="user-submenu">
                <li>
                  <Link to="/perfil/senha">
                    <FaKey />
                    <span>Alterar Senha</span>
                  </Link>
                </li>
                <li>
                  <button onClick={handleLogout} className="app-logout">
                    <FaSignOutAlt />
                    <span>Sair</span>
                  </button>
                </li>
              </ul>
            </li>
          </ul>
        </nav>
      </div>
    </header>
  );
}

export default Header;
