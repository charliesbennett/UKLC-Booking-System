import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export function useGroups(filters = {}) {
  const [groups, setGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetch() {
      setLoading(true)
      let query = supabase
        .from('groups')
        .select(`
          id,
          group_number,
          name,
          status,
          nationality,
          arrival_date,
          departure_date,
          year,
          agents ( id, name ),
          centres ( id, name, short_name ),
          programmes ( id, name ),
          coordinator:staff ( id, name, code )
        `)
        .order('arrival_date', { ascending: true })

      if (filters.status) query = query.eq('status', filters.status)
      if (filters.centre_id) query = query.eq('centre_id', filters.centre_id)
      if (filters.year) query = query.eq('year', filters.year)

      const { data, error } = await query
      setGroups(data ?? [])
      setError(error)
      setLoading(false)
    }
    fetch()
  }, [filters.status, filters.centre_id, filters.year])

  return { groups, loading, error }
}

export function useGroup(id) {
  const [group, setGroup] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (!id || id === 'new') {
      setGroup(null)
      setLoading(false)
      return
    }
    async function fetch() {
      const { data, error } = await supabase
        .from('groups')
        .select('*')
        .eq('id', id)
        .single()
      setGroup(data)
      setError(error)
      setLoading(false)
    }
    fetch()
  }, [id])

  return { group, loading, error }
}
