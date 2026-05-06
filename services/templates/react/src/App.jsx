import React from 'react'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080'

function App() {
  const [message, setMessage] = React.useState('')

  React.useEffect(() => {
    fetch(`${API_URL}/`)
      .then(res => res.text())
      .then(setMessage)
      .catch(() => setMessage('Backend not available'))
  }, [])

  return (
    <div>
      <h1>React App</h1>
      <p>Backend says: {message}</p>
    </div>
  )
}

export default App
