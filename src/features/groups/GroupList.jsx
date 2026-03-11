import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useGroups } from '../../hooks/useGroups'
import styles from './GroupList.module.css'

const STATUS_LABELS = {
  provisional: { label: 'Provisional', className: 'provisional' },
  confirmed:   { label: 'Confirmed',   className: 'confirmed'   },
  cancelled:   { label: 'Cancelled',   className: 'cancelled'   },
}

function StatusBadge({ status }) {
  const s = STATUS_LABELS[status] ?? { label: status, className: '' }
  return <span className={`${styles.badge} ${styles[s.className]}`}>{s.label}</span>
}

function formatDate(date) {
  if (!date) return '—'
  return new Date(date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

export default function GroupList() {
  const navigate = useNavigate()
  const [filters, setFilters] = useState({ status: '', centre_id: '', year: new Date().getFullYear() })
  const { groups, loading, error } = useGroups(filters)

  function setFilter(key, value) {
    setFilters(f => ({ ...f, [key]: value }))
  }

  return (
    <div>
      <div className={styles.toolbar}>
        <div className={styles.toolbarLeft}>
          <h1 className={styles.title}>Groups</h1>
          <span className={styles.count}>{loading ? '…' : groups.length}</span>
        </div>
        <div className={styles.filters}>
          <select value={filters.status} onChange={e => setFilter('status', e.target.value)}>
            <option value="">All statuses</option>
            <option value="provisional">Provisional</option>
            <option value="confirmed">Confirmed</option>
            <option value="cancelled">Cancelled</option>
          </select>
          <select value={filters.year} onChange={e => setFilter('year', e.target.value)}>
            <option value="2026">2026</option>
            <option value="2025">2025</option>
          </select>
        </div>
        <button className={styles.newButton} onClick={() => navigate('/groups/new')}>
          + New group
        </button>
      </div>

      {error && <p className={styles.error}>Error loading groups: {error.message}</p>}

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Ref</th>
              <th>Group name</th>
              <th>Agent</th>
              <th>Centre</th>
              <th>Status</th>
              <th>Arrival</th>
              <th>Departure</th>
              <th>Coordinator</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr><td colSpan={8} className={styles.empty}>Loading…</td></tr>
            )}
            {!loading && groups.length === 0 && (
              <tr><td colSpan={8} className={styles.empty}>No groups found.</td></tr>
            )}
            {groups.map(g => (
              <tr key={g.id} className={styles.row} onClick={() => navigate(`/groups/${g.id}`)}>
                <td className={styles.mono}>{g.group_number ?? '—'}</td>
                <td className={styles.groupName}>{g.name ?? '—'}</td>
                <td>{g.agents?.name ?? '—'}</td>
                <td>{g.centres?.short_name ?? g.centres?.name ?? '—'}</td>
                <td><StatusBadge status={g.status} /></td>
                <td>{formatDate(g.arrival_date)}</td>
                <td>{formatDate(g.departure_date)}</td>
                <td>{g.coordinator?.code ?? g.coordinator?.name ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
