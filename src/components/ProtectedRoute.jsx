import { Navigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function ProtectedRoute({ children }) {
  const { session } = useAuth()

  // Still loading initial session
  if (session === undefined) return null

  if (!session) return <Navigate to="/login" replace />

  return children
}
