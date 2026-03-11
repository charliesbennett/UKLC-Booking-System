import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useGroup } from '../../hooks/useGroups'
import { useAuth } from '../../contexts/AuthContext'
import styles from './GroupDetail.module.css'

const EMPTY_GROUP = {
  group_number: '',
  name: '',
  agent_id: '',
  centre_id: '',
  programme_id: '',
  coordinator_id: '',
  status: 'provisional',
  nationality: '',
  year: new Date().getFullYear(),
  arrival_date: '',
  departure_date: '',
  arrival_flight: '',
  arrival_time: '',
  arrival_airport: '',
  arrival_meal: 'none',
  arrival_transfer: false,
  arrival_transfer_provider: '',
  departure_flight: '',
  departure_time: '',
  departure_airport: '',
  departure_meal: 'none',
  departure_transfer: false,
  gl_mobile: '',
  agent_emergency_contact: '',
  non_standard_programme: false,
  gcs_notes: '',
  internal_notes: '',
  programme_notes: '',
  date_confirmed: '',
}

export default function GroupDetail() {
  const { id } = useParams()
  const isNew = id === 'new'
  const navigate = useNavigate()
  const { staffProfile } = useAuth()

  const { group, loading: groupLoading } = useGroup(id)
  const [form, setForm] = useState(EMPTY_GROUP)
  const [agents, setAgents] = useState([])
  const [centres, setCentres] = useState([])
  const [programmes, setProgrammes] = useState([])
  const [staffList, setStaffList] = useState([])
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)

  // Load dropdown data
  useEffect(() => {
    if (!staffProfile) return
    const org = staffProfile.organisation_id
    Promise.all([
      supabase.from('agents').select('id, name').eq('organisation_id', org).eq('status', 'active').order('name'),
      supabase.from('centres').select('id, name, short_name').eq('organisation_id', org).eq('active', true).order('name'),
      supabase.from('programmes').select('id, name, year').eq('organisation_id', org).order('year', { ascending: false }),
      supabase.from('staff').select('id, name, code, role').eq('organisation_id', org).eq('active', true).order('name'),
    ]).then(([a, c, p, s]) => {
      setAgents(a.data ?? [])
      setCentres(c.data ?? [])
      setProgrammes(p.data ?? [])
      setStaffList(s.data ?? [])
    })
  }, [staffProfile])

  // Populate form when editing
  useEffect(() => {
    if (group) {
      setForm({
        ...EMPTY_GROUP,
        ...group,
        arrival_date:    group.arrival_date    ?? '',
        departure_date:  group.departure_date  ?? '',
        arrival_time:    group.arrival_time    ?? '',
        departure_time:  group.departure_time  ?? '',
        date_confirmed:  group.date_confirmed  ?? '',
        agent_id:        group.agent_id        ?? '',
        centre_id:       group.centre_id       ?? '',
        programme_id:    group.programme_id    ?? '',
        coordinator_id:  group.coordinator_id  ?? '',
      })
    }
  }, [group])

  function setField(key, value) {
    setForm(f => ({ ...f, [key]: value }))
  }

  async function handleSave(e) {
    e.preventDefault()
    setSaving(true)
    setError(null)

    const payload = {
      ...form,
      organisation_id: staffProfile.organisation_id,
      // Convert empty strings to null for FK and date fields
      agent_id:        form.agent_id        || null,
      centre_id:       form.centre_id       || null,
      programme_id:    form.programme_id    || null,
      coordinator_id:  form.coordinator_id  || null,
      arrival_date:    form.arrival_date    || null,
      departure_date:  form.departure_date  || null,
      arrival_time:    form.arrival_time    || null,
      departure_time:  form.departure_time  || null,
      date_confirmed:  form.date_confirmed  || null,
      year:            form.year            || null,
    }

    let result
    if (isNew) {
      result = await supabase.from('groups').insert(payload).select().single()
    } else {
      result = await supabase.from('groups').update(payload).eq('id', id).select().single()
    }

    setSaving(false)
    if (result.error) {
      setError(result.error.message)
    } else {
      navigate('/groups')
    }
  }

  if (groupLoading) return <div className={styles.loading}>Loading…</div>

  const coordinators = staffList.filter(s => ['coordinator', 'operations', 'admin'].includes(s.role))

  return (
    <div className={styles.page}>
      <div className={styles.pageHeader}>
        <button className={styles.back} onClick={() => navigate('/groups')}>← Groups</button>
        <h1 className={styles.title}>
          {isNew ? 'New group' : (form.group_number ? `${form.group_number} — ${form.name || 'Unnamed'}` : form.name || 'Group detail')}
        </h1>
        {!isNew && (
          <span className={`${styles.statusBadge} ${styles[form.status]}`}>{form.status}</span>
        )}
      </div>

      {error && <p className={styles.error}>{error}</p>}

      <form onSubmit={handleSave} className={styles.form}>

        {/* ── Overview ── */}
        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Overview</h2>
          <div className={styles.grid}>
            <div className={styles.field}>
              <label>Group number</label>
              <input value={form.group_number} onChange={e => setField('group_number', e.target.value)} placeholder="Auto-generated if blank" />
            </div>
            <div className={styles.field}>
              <label>Group name</label>
              <input value={form.name} onChange={e => setField('name', e.target.value)} placeholder="e.g. Sunho Business" />
            </div>
            <div className={styles.field}>
              <label>Status</label>
              <select value={form.status} onChange={e => setField('status', e.target.value)}>
                <option value="provisional">Provisional</option>
                <option value="confirmed">Confirmed</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </div>
            <div className={styles.field}>
              <label>Year</label>
              <input type="number" value={form.year} onChange={e => setField('year', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Agent</label>
              <select value={form.agent_id} onChange={e => setField('agent_id', e.target.value)}>
                <option value="">— Select agent —</option>
                {agents.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
              </select>
            </div>
            <div className={styles.field}>
              <label>Centre</label>
              <select value={form.centre_id} onChange={e => setField('centre_id', e.target.value)}>
                <option value="">— Select centre —</option>
                {centres.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
            <div className={styles.field}>
              <label>Programme</label>
              <select value={form.programme_id} onChange={e => setField('programme_id', e.target.value)}>
                <option value="">— Select programme —</option>
                {programmes.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
              </select>
            </div>
            <div className={styles.field}>
              <label>Coordinator</label>
              <select value={form.coordinator_id} onChange={e => setField('coordinator_id', e.target.value)}>
                <option value="">— Select coordinator —</option>
                {coordinators.map(s => (
                  <option key={s.id} value={s.id}>{s.name}{s.code ? ` (${s.code})` : ''}</option>
                ))}
              </select>
            </div>
            <div className={styles.field}>
              <label>Nationality</label>
              <input value={form.nationality} onChange={e => setField('nationality', e.target.value)} placeholder="e.g. Italian" />
            </div>
            <div className={styles.field}>
              <label>Date confirmed</label>
              <input type="date" value={form.date_confirmed} onChange={e => setField('date_confirmed', e.target.value)} />
            </div>
            <div className={`${styles.field} ${styles.checkField}`}>
              <label>
                <input type="checkbox" checked={form.non_standard_programme} onChange={e => setField('non_standard_programme', e.target.checked)} />
                Non-standard programme
              </label>
            </div>
          </div>
        </section>

        {/* ── Arrival ── */}
        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Arrival</h2>
          <div className={styles.grid}>
            <div className={styles.field}>
              <label>Arrival date</label>
              <input type="date" value={form.arrival_date} onChange={e => setField('arrival_date', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Flight number</label>
              <input value={form.arrival_flight} onChange={e => setField('arrival_flight', e.target.value)} placeholder="e.g. BA256" />
            </div>
            <div className={styles.field}>
              <label>Flight time</label>
              <input type="time" value={form.arrival_time} onChange={e => setField('arrival_time', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Airport</label>
              <input value={form.arrival_airport} onChange={e => setField('arrival_airport', e.target.value)} placeholder="e.g. LHR" />
            </div>
            <div className={styles.field}>
              <label>Arrival meal</label>
              <select value={form.arrival_meal} onChange={e => setField('arrival_meal', e.target.value)}>
                <option value="none">None</option>
                <option value="breakfast">Breakfast</option>
                <option value="lunch">Lunch</option>
                <option value="dinner">Dinner</option>
              </select>
            </div>
            <div className={`${styles.field} ${styles.checkField}`}>
              <label>
                <input type="checkbox" checked={form.arrival_transfer} onChange={e => setField('arrival_transfer', e.target.checked)} />
                Transfer required
              </label>
            </div>
            {form.arrival_transfer && (
              <div className={styles.field}>
                <label>Transfer provider</label>
                <input value={form.arrival_transfer_provider} onChange={e => setField('arrival_transfer_provider', e.target.value)} placeholder="Coach/driver company" />
              </div>
            )}
          </div>
        </section>

        {/* ── Departure ── */}
        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Departure</h2>
          <div className={styles.grid}>
            <div className={styles.field}>
              <label>Departure date</label>
              <input type="date" value={form.departure_date} onChange={e => setField('departure_date', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Flight number</label>
              <input value={form.departure_flight} onChange={e => setField('departure_flight', e.target.value)} placeholder="e.g. BA257" />
            </div>
            <div className={styles.field}>
              <label>Flight time</label>
              <input type="time" value={form.departure_time} onChange={e => setField('departure_time', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Airport</label>
              <input value={form.departure_airport} onChange={e => setField('departure_airport', e.target.value)} placeholder="e.g. LHR" />
            </div>
            <div className={styles.field}>
              <label>Departure meal</label>
              <select value={form.departure_meal} onChange={e => setField('departure_meal', e.target.value)}>
                <option value="none">None</option>
                <option value="breakfast">Breakfast</option>
                <option value="lunch">Lunch</option>
                <option value="dinner">Dinner</option>
              </select>
            </div>
            <div className={`${styles.field} ${styles.checkField}`}>
              <label>
                <input type="checkbox" checked={form.departure_transfer} onChange={e => setField('departure_transfer', e.target.checked)} />
                Transfer required
              </label>
            </div>
          </div>
        </section>

        {/* ── Contacts ── */}
        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Contacts</h2>
          <div className={styles.grid}>
            <div className={styles.field}>
              <label>Group leader mobile</label>
              <input value={form.gl_mobile} onChange={e => setField('gl_mobile', e.target.value)} placeholder="+44..." />
            </div>
            <div className={styles.field}>
              <label>Agent emergency contact</label>
              <input value={form.agent_emergency_contact} onChange={e => setField('agent_emergency_contact', e.target.value)} />
            </div>
          </div>
        </section>

        {/* ── Notes ── */}
        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Notes</h2>
          <div className={styles.stack}>
            <div className={styles.field}>
              <label>GCS notes <span className={styles.hint}>(Group Confirmation Sheet)</span></label>
              <textarea rows={3} value={form.gcs_notes} onChange={e => setField('gcs_notes', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Programme notes</label>
              <textarea rows={3} value={form.programme_notes} onChange={e => setField('programme_notes', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label>Internal notes</label>
              <textarea rows={3} value={form.internal_notes} onChange={e => setField('internal_notes', e.target.value)} />
            </div>
          </div>
        </section>

        <div className={styles.actions}>
          <button type="button" className={styles.cancel} onClick={() => navigate('/groups')}>Cancel</button>
          <button type="submit" className={styles.save} disabled={saving}>
            {saving ? 'Saving…' : isNew ? 'Create group' : 'Save changes'}
          </button>
        </div>
      </form>
    </div>
  )
}
