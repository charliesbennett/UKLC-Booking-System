import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import styles from './Layout.module.css'

export default function Layout() {
  const { staffProfile, signOut } = useAuth()
  const navigate = useNavigate()

  async function handleSignOut() {
    await signOut()
    navigate('/login')
  }

  return (
    <div className={styles.shell}>
      <header className={styles.header}>
        <div className={styles.brand}>
          <span className={styles.logo}>UKLC</span>
          <span className={styles.appName}>Booking System</span>
        </div>
        <nav className={styles.nav}>
          <NavLink
            to="/groups"
            className={({ isActive }) => isActive ? `${styles.navLink} ${styles.active}` : styles.navLink}
          >
            Bookings
          </NavLink>
          <span className={styles.navLinkDisabled} title="Coming in Phase 2">Sales Pipeline</span>
          <span className={styles.navLinkDisabled} title="Coming in Phase 2">Centre View</span>
        </nav>
        <div className={styles.user}>
          {staffProfile && (
            <span className={styles.userName}>
              {staffProfile.name}
              <span className={styles.roleTag}>{staffProfile.role}</span>
            </span>
          )}
          <button className={styles.signOut} onClick={handleSignOut}>Sign out</button>
        </div>
      </header>
      <main className={styles.main}>
        <Outlet />
      </main>
    </div>
  )
}
