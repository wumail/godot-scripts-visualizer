/**
 * WebSocket connection for real-time communication with Godot
 */

let ws = null;
let wsConnected = false;
let staticPreview = false;
let httpCommandMode = false;
const pendingRequests = new Map();
let requestId = 0;
const transportState = {
  mode: 'disconnected',
  status: 'idle',
  label: 'Idle',
  detail: '',
  lastError: ''
};

function emitTransportState() {
  document.dispatchEvent(new CustomEvent('visualizer-transport-state', {
    detail: { ...transportState }
  }));
}

function setTransportState(nextState) {
  Object.assign(transportState, nextState);
  emitTransportState();
}

async function probeHttpTransport() {
  const healthUrl = window.GODOT_VISUALIZER_HEALTH_URL || '/health';
  setTransportState({
    mode: 'http',
    status: 'connecting',
    label: 'Connecting',
    detail: 'Checking localhost host',
    lastError: ''
  });

  try {
    const response = await fetch(healthUrl, { cache: 'no-store' });
    const payload = await response.json();
    if (!response.ok || payload.ok !== true) {
      throw new Error(payload.error || `HTTP ${response.status}`);
    }

    wsConnected = true;
    setTransportState({
      mode: 'http',
      status: 'connected',
      label: 'Connected',
      detail: payload.port ? `HTTP commands on :${payload.port}` : 'HTTP command host ready',
      lastError: ''
    });
  } catch (error) {
    wsConnected = false;
    setTransportState({
      mode: 'http',
      status: 'error',
      label: 'Host unreachable',
      detail: error.message,
      lastError: error.message
    });
  }
}

export function connectWebSocket() {
  staticPreview = window.location.protocol === 'file:' || window.GODOT_VISUALIZER_STATIC === true;
  httpCommandMode = window.GODOT_VISUALIZER_HTTP_COMMANDS === true;

  if (staticPreview) {
    wsConnected = false;
    setTransportState({
      mode: 'static',
      status: 'static-preview',
      label: 'Static preview',
      detail: 'Read-only mode',
      lastError: ''
    });
    console.log('[visualizer] Static preview mode enabled');
    return;
  }

  if (httpCommandMode) {
    wsConnected = false;
    probeHttpTransport();
    console.log('[visualizer] HTTP command transport enabled');
    return;
  }

  setTransportState({
    mode: 'websocket',
    status: 'connecting',
    label: 'Connecting',
    detail: 'Opening WebSocket transport',
    lastError: ''
  });

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  ws = new WebSocket(`${protocol}//${window.location.host}`);

  ws.onopen = () => {
    wsConnected = true;
    setTransportState({
      mode: 'websocket',
      status: 'connected',
      label: 'Connected',
      detail: 'WebSocket transport active',
      lastError: ''
    });
    console.log('[visualizer] WebSocket connected');
  };

  ws.onclose = () => {
    wsConnected = false;
    setTransportState({
      mode: 'websocket',
      status: 'reconnecting',
      label: 'Reconnecting',
      detail: 'Retrying in 2s',
      lastError: transportState.lastError
    });
    console.log('[visualizer] WebSocket disconnected, reconnecting...');
    setTimeout(connectWebSocket, 2000);
  };

  ws.onerror = (err) => {
    setTransportState({
      mode: 'websocket',
      status: 'error',
      label: 'Connection error',
      detail: 'WebSocket transport failed',
      lastError: 'WebSocket transport failed'
    });
    console.error('[visualizer] WebSocket error:', err);
  };

  ws.onmessage = (event) => {
    try {
      const msg = JSON.parse(event.data);
      if (msg.id && pendingRequests.has(msg.id)) {
        const { resolve, reject } = pendingRequests.get(msg.id);
        pendingRequests.delete(msg.id);
        if (msg.error) {
          reject(new Error(msg.error));
        } else {
          resolve(msg.result || msg);
        }
      }
    } catch (err) {
      console.error('[visualizer] Failed to parse message:', err);
    }
  };
}

export function sendCommand(command, args) {
  if (httpCommandMode) {
    return fetch(window.GODOT_VISUALIZER_COMMAND_URL || '/command', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ command, args })
    }).then(async (response) => {
      const payload = await response.json();
      if (!response.ok || payload?.ok === false || payload?.error) {
        const errorMessage = payload?.error || `HTTP ${response.status}`;
        setTransportState({
          mode: 'http',
          status: 'error',
          label: 'Command failed',
          detail: errorMessage,
          lastError: errorMessage
        });
        throw new Error(errorMessage);
      }

      setTransportState({
        mode: 'http',
        status: 'connected',
        label: 'Connected',
        detail: `Last command: ${command}`,
        lastError: ''
      });
      return payload;
    }).catch((error) => {
      setTransportState({
        mode: 'http',
        status: 'error',
        label: 'Command failed',
        detail: error.message,
        lastError: error.message
      });
      throw error;
    });
  }

  return new Promise((resolve, reject) => {
    if (staticPreview) {
      reject(new Error('Transport unavailable in static preview mode'));
      return;
    }

    if (!wsConnected || !ws) {
      setTransportState({
        mode: 'websocket',
        status: 'error',
        label: 'Not connected',
        detail: 'WebSocket not connected',
        lastError: 'WebSocket not connected'
      });
      reject(new Error('WebSocket not connected'));
      return;
    }

    const id = ++requestId;
    pendingRequests.set(id, { resolve, reject });

    ws.send(JSON.stringify({
      type: 'visualizer_command',
      id,
      command,
      args
    }));

    // Timeout after 30 seconds
    setTimeout(() => {
      if (pendingRequests.has(id)) {
        pendingRequests.delete(id);
        reject(new Error('Request timeout'));
      }
    }, 30000);
  });
}

export function isConnected() {
  return wsConnected;
}

export function isStaticPreview() {
  return staticPreview;
}

export function getTransportState() {
  return { ...transportState };
}

export function reconnectTransport() {
  if (staticPreview) {
    setTransportState({
      mode: 'static',
      status: 'static-preview',
      label: 'Static preview',
      detail: 'Reconnect is unavailable in static preview',
      lastError: ''
    });
    return;
  }

  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.close();
  }

  connectWebSocket();
}
