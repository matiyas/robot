// Robot controller - main UI logic
class RobotController {
  constructor() {
    this.api = new RobotAPI();
    this.isConnected = false;
    this.movementDuration = 200; // ms for button press
    this.turretDuration = 300; // ms for turret rotation

    this.init();
  }

  async init() {
    console.log('Initializing Robot Controller...');

    // Setup button event listeners
    this.setupMovementControls();
    this.setupTurretControls();
    this.setupEmergencyStop();

    // Load camera stream
    await this.loadCameraStream();

    // Check connection status
    await this.checkStatus();

    // Periodic status check
    setInterval(() => this.checkStatus(), 5000);

    console.log('Robot Controller initialized');
  }

  setupMovementControls() {
    const directions = ['forward', 'backward', 'left', 'right'];

    directions.forEach(direction => {
      const btn = document.getElementById(`btn${this.capitalize(direction)}`);
      if (btn) {
        this.setupButton(btn, () => this.move(direction));
      }
    });
  }

  setupTurretControls() {
    const btnLeft = document.getElementById('btnTurretLeft');
    const btnRight = document.getElementById('btnTurretRight');

    if (btnLeft) {
      this.setupButton(btnLeft, () => this.turret('left'));
    }

    if (btnRight) {
      this.setupButton(btnRight, () => this.turret('right'));
    }
  }

  setupEmergencyStop() {
    const btnStop = document.getElementById('btnStop');
    if (btnStop) {
      btnStop.addEventListener('click', () => this.emergencyStop());
    }
  }

  setupButton(button, action) {
    // Support both mouse and touch events
    let pressTimer = null;
    let isPressed = false;

    const startPress = (e) => {
      e.preventDefault();
      if (isPressed) return;

      isPressed = true;
      button.classList.add('active');

      // Execute action
      action();

      console.log(`Button pressed: ${button.id}`);
    };

    const endPress = (e) => {
      if (!isPressed) return;

      isPressed = false;
      button.classList.remove('active');

      console.log(`Button released: ${button.id}`);
    };

    // Mouse events
    button.addEventListener('mousedown', startPress);
    button.addEventListener('mouseup', endPress);
    button.addEventListener('mouseleave', endPress);

    // Touch events
    button.addEventListener('touchstart', startPress);
    button.addEventListener('touchend', endPress);
    button.addEventListener('touchcancel', endPress);
  }

  async move(direction) {
    try {
      const result = await this.api.move(direction, this.movementDuration);
      console.log('Move command sent:', result);
    } catch (error) {
      console.error('Move failed:', error);
      this.showError('Movement command failed');
    }
  }

  async turret(direction) {
    try {
      const result = await this.api.turret(direction, this.turretDuration);
      console.log('Turret command sent:', result);
    } catch (error) {
      console.error('Turret command failed:', error);
      this.showError('Turret command failed');
    }
  }

  async emergencyStop() {
    try {
      const result = await this.api.stop();
      console.log('Emergency stop:', result);
      this.showStatus('STOPPED', 'error');
    } catch (error) {
      console.error('Emergency stop failed:', error);
      this.showError('Emergency stop failed');
    }
  }

  async loadCameraStream() {
    try {
      const response = await this.api.getCameraUrl();
      const streamUrl = response.stream_url;

      const cameraImg = document.getElementById('cameraStream');
      const cameraError = document.getElementById('cameraError');

      cameraImg.onload = () => {
        cameraError.style.display = 'none';
        console.log('Camera stream loaded');
      };

      cameraImg.onerror = () => {
        cameraError.style.display = 'block';
        console.warn('Camera stream unavailable');
      };

      cameraImg.src = streamUrl;
    } catch (error) {
      console.error('Failed to load camera stream:', error);
      document.getElementById('cameraError').style.display = 'block';
    }
  }

  async checkStatus() {
    try {
      const status = await this.api.getStatus();
      this.isConnected = status.connected;
      this.updateStatusUI(true);
    } catch (error) {
      this.isConnected = false;
      this.updateStatusUI(false);
      console.error('Status check failed:', error);
    }
  }

  updateStatusUI(connected) {
    const statusElement = document.getElementById('status');
    const statusText = document.getElementById('statusText');

    if (connected) {
      statusElement.classList.remove('disconnected');
      statusElement.classList.add('connected');
      statusText.textContent = 'Connected';
    } else {
      statusElement.classList.remove('connected');
      statusElement.classList.add('disconnected');
      statusText.textContent = 'Disconnected';
    }
  }

  showStatus(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
    // Could be extended to show toast notifications
  }

  showError(message) {
    this.showStatus(message, 'error');
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }
}

// Initialize controller when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.robotController = new RobotController();
  });
} else {
  window.robotController = new RobotController();
}
