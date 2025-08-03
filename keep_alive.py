#!/usr/bin/env python3
"""
Keep Alive Server

A simple Flask web server to keep the Twitch Channel Points Miner application
alive on cloud platforms like Replit, Heroku, or similar services that require
an HTTP endpoint to prevent the application from sleeping.

Features:
- Health check endpoint
- Status information
- Configurable port and host
- Proper logging and error handling
- Graceful shutdown support
"""

import logging
import os
import signal
import sys
import time
from datetime import datetime
from threading import Event, Thread
from typing import Optional

from flask import Flask, jsonify, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global variables
app = Flask(__name__)
server_thread: Optional[Thread] = None
shutdown_event = Event()
start_time = time.time()


@app.route('/')
def main() -> str:
    """Main endpoint - simple status message."""
    return "🎮 Twitch Channel Points Miner is running and healthy!"


@app.route('/health')
def health_check():
    """Health check endpoint with detailed status information."""
    uptime_seconds = time.time() - start_time
    uptime_minutes = uptime_seconds / 60
    uptime_hours = uptime_minutes / 60

    # Format uptime nicely
    if uptime_hours >= 1:
        uptime_str = f"{uptime_hours:.1f} hours"
    elif uptime_minutes >= 1:
        uptime_str = f"{uptime_minutes:.1f} minutes"
    else:
        uptime_str = f"{uptime_seconds:.1f} seconds"

    health_data = {
        "status": "healthy",
        "service": "Twitch Channel Points Miner",
        "timestamp": datetime.now().isoformat(),
        "uptime": uptime_str,
        "uptime_seconds": round(uptime_seconds, 2),
        "version": "2.0",
        "host": request.host,
        "user_agent": request.headers.get('User-Agent', 'Unknown'),
        "environment": {
            "python_version": sys.version.split()[0],
            "port": os.environ.get('PORT', '6060'),
            "host": os.environ.get('HOST', '0.0.0.0'),
        }
    }

    return jsonify(health_data)


@app.route('/status')
def status():
    """Detailed status endpoint."""
    return jsonify({
        "service": "Twitch Channel Points Miner Keep-Alive Server",
        "status": "running",
        "uptime_seconds": round(time.time() - start_time, 2),
        "thread_active": (server_thread is not None and
                          server_thread.is_alive()),
        "shutdown_requested": shutdown_event.is_set(),
        "endpoints": ["/", "/health", "/status"],
        "timestamp": datetime.now().isoformat()
    })


@app.route('/ping')
def ping() -> str:
    """Simple ping endpoint."""
    return "pong"


def signal_handler(signum: int, frame) -> None:
    """Handle shutdown signals gracefully."""
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_event.set()


def run_server() -> None:
    """Run the Flask server with proper error handling."""
    try:
        host = os.environ.get('HOST', '0.0.0.0')
        port = int(os.environ.get('PORT', 6060))

        logger.info(f"Starting keep-alive server on {host}:{port}")

        # Disable Flask's default request logging in production
        if os.environ.get('FLASK_ENV') != 'development':
            log = logging.getLogger('werkzeug')
            log.setLevel(logging.WARNING)

        app.run(
            host=host,
            port=port,
            debug=False,
            use_reloader=False,
            threaded=True
        )
    except Exception as e:
        logger.error(f"Failed to start keep-alive server: {e}")
        shutdown_event.set()


def keep_alive() -> None:
    """
    Start the keep-alive server in a separate daemon thread.

    This function starts a Flask web server that responds to HTTP requests,
    preventing the application from being put to sleep by cloud platforms.
    """
    global server_thread

    if server_thread is not None and server_thread.is_alive():
        logger.warning("Keep-alive server is already running")
        return

    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Start the server in a daemon thread
    server_thread = Thread(target=run_server, name="KeepAliveServer")
    server_thread.daemon = True  # Dies when main thread dies
    server_thread.start()

    logger.info("Keep-alive server thread started")


def stop_server() -> None:
    """Stop the keep-alive server gracefully."""
    global server_thread

    logger.info("Stopping keep-alive server...")
    shutdown_event.set()

    if server_thread is not None and server_thread.is_alive():
        # Give the server some time to shutdown gracefully
        server_thread.join(timeout=5.0)
        if server_thread.is_alive():
            logger.warning("Keep-alive server did not shutdown gracefully")
        else:
            logger.info("Keep-alive server stopped successfully")

    server_thread = None


def is_server_running() -> bool:
    """Check if the keep-alive server is currently running."""
    return server_thread is not None and server_thread.is_alive()


if __name__ == '__main__':
    # If run directly, start the server and keep it running
    try:
        keep_alive()
        logger.info("Keep-alive server is running. Press Ctrl+C to stop.")

        # Keep the main thread alive
        while not shutdown_event.is_set():
            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    finally:
        stop_server()
        logger.info("Keep-alive server shutdown complete")
