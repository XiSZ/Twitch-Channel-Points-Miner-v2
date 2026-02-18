# -*- coding: utf-8 -*-
import logging
import os
import subprocess
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


def configure_logger() -> logging.Logger:
    logger = logging.getLogger(__name__)
    _handler = logging.StreamHandler()
    _handler.setFormatter(
        logging.Formatter(
            "%(asctime)s - %(levelname)s - %(module)s - [%(funcName)s]: %(message)s",
            datefmt="%d/%m/%y %H:%M:%S",
        )
    )
    logger.addHandler(_handler)
    logger.setLevel(logging.INFO)
    return logger


logger = configure_logger()


class WebRequestError(Exception):
    """Error class for GitHub API request failures with troubleshooting hints."""

    def __init__(self, code: int) -> None:
        sep = "\n     \u2713 "
        if code == 401:
            self.message = "Authorization token is invalid or expired."
            self.hint = sep.join(
                [
                    "",
                    "Ensure that GITHUB_TOKEN was set correctly.",
                    "Verify that the token has not expired.",
                    "Check that the token has the required permissions (repo access).",
                    "Ensure the token format is valid (should start with ghp_, github_pat_, etc.).",
                ]
            )
        elif code == 404:
            self.message = "Requested file could not be found."
            self.hint = sep.join(
                [
                    "",
                    "Ensure that CJ_OWNER and CJ_REPO were set and point to the private repository.",
                    "Ensure that CJ_FILE was set and points to a file that exists in the repository.",
                ]
            )
        else:
            self.message = f"Unexpected error. Status code: {code}"
            self.hint = None

        super().__init__(self.message)
        self.code = code

    def troubleshoot(self) -> None:
        logger.error(self)
        if self.hint is not None:
            logger.info(f"{self}\n  Troubleshooting:{self.hint}")

    def __str__(self) -> str:
        return f"{self.__class__.__name__} -> {self.message}"


def check_required_env_vars() -> dict:
    """Check that core Twitch credentials are set. Returns all env values."""
    env_values = {}

    # Required: Twitch credentials
    for key in ["USER", "PASSWORD"]:
        value = os.getenv(key)
        if value is None:
            logger.error(f"{key} environment variable is not defined. Set it in the .env file.")
            raise EnvironmentError(f"{key} environment variable is not defined.")
        logger.info(f"{key} environment variable is set.")
        env_values[key] = value

    # Optional: notification settings
    for key in ["WEBHOOK", "CHATID", "TELEGRAMTOKEN"]:
        value = os.getenv(key)
        if value:
            logger.info(f"{key} environment variable is set.")
        else:
            logger.info(f"{key} environment variable is not set (optional, skipping).")
        env_values[key] = value

    # Optional: GitHub cookie storage (all must be set together if any are used)
    github_keys = ["GITHUB_TOKEN", "CJ_OWNER", "CJ_REPO", "CJ_FILE"]
    github_values = {k: os.getenv(k) for k in github_keys}
    any_set = any(v for v in github_values.values())
    all_set = all(v for v in github_values.values())

    if any_set and not all_set:
        missing = [k for k, v in github_values.items() if not v]
        logger.error(
            f"Partial GitHub configuration detected. Missing: {', '.join(missing)}. "
            "Either set all of GITHUB_TOKEN, CJ_OWNER, CJ_REPO, CJ_FILE or none of them."
        )
        raise EnvironmentError(f"Missing GitHub environment variables: {', '.join(missing)}")

    if all_set:
        for key in github_keys:
            logger.info(f"{key} environment variable is set.")

    env_values.update(github_values)
    return env_values


def validate_github_token(token: str) -> None:
    """Validate the GitHub token format and check if it's active."""
    logger.info("Validating GitHub token...")

    valid_prefixes = ("ghp_", "github_pat_", "gho_", "ghu_", "ghs_", "ghr_")
    if not token.startswith(valid_prefixes):
        logger.error("Invalid GitHub token format.")
        raise WebRequestError(401)

    try:
        response = requests.get(
            "https://api.github.com/user",
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github.v3+json",
            },
            timeout=30,
        )
        if response.status_code == 200:
            user_data = response.json()
            logger.info(
                f"GitHub token validated successfully for user: {user_data.get('login', 'Unknown')}"
            )
        elif response.status_code == 401:
            logger.error("GitHub token is invalid or expired.")
            raise WebRequestError(401)
        else:
            logger.warning(
                f"Unexpected response during token validation: {response.status_code}"
            )
    except requests.exceptions.RequestException as e:
        logger.warning(f"Network error during token validation: {e}")


def download_cookie_from_github(token: str, owner: str, repo: str, cookie_file: str) -> None:
    """Download a cookie file from a private GitHub repository."""
    url = f"https://api.github.com/repos/{owner}/{repo}/contents/{cookie_file}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json",
    }

    logger.info(f"Downloading cookie file from GitHub: {owner}/{repo}/{cookie_file}")
    response = requests.get(url, headers=headers, timeout=60)

    if response.status_code != 200:
        logger.error(f"Request failed with status code: {response.status_code}")
        raise WebRequestError(response.status_code)

    file_info = response.json()
    file_path = Path.cwd() / "cookies" / file_info["name"]
    download_url = file_info["download_url"]

    # Ensure the cookies directory exists
    file_path.parent.mkdir(parents=True, exist_ok=True)

    file_download = requests.get(download_url, timeout=60)
    with open(file_path, "wb") as f:
        f.write(file_download.content)

    logger.info(f"Cookie file saved to '{file_path}'")


def verify_cookies(cookie_filename: str | None = None) -> None:
    """Verify that the cookies directory and (optionally) the cookie file exist."""
    cookies_path = Path.cwd() / "cookies"

    if not cookies_path.exists():
        logger.error("cookies directory does not exist.")
        raise FileNotFoundError("cookies directory does not exist.")

    logger.info(f"Cookies directory found: {cookies_path}")

    if cookie_filename:
        cookie_file_path = cookies_path / cookie_filename
        if not cookie_file_path.exists():
            logger.error(f"Cookie file not found: {cookie_file_path}")
            raise FileNotFoundError(f"Cookie file not found: {cookie_file_path}")
        logger.info(f"Cookie file found: {cookie_file_path}")


def start_miner() -> None:
    """Start run.py as a subprocess."""
    entrypoint = Path.cwd() / "run.py"
    if not entrypoint.exists():
        logger.error(f"Entrypoint not found: {entrypoint}")
        raise FileNotFoundError(f"Entrypoint not found: {entrypoint}")

    logger.info("Starting run.py...")
    try:
        subprocess.run([sys.executable, str(entrypoint)], check=True)
    except subprocess.CalledProcessError as e:
        logger.critical(f"run.py exited with error: {e}")
        sys.exit(1)


def main():
    logger.info("=== localRunner - Pre-flight checks ===")

    # Step 1: Validate environment variables
    env_values = check_required_env_vars()

    # Step 2: If GitHub config is present, download cookies from GitHub
    gh_token = env_values.get("GITHUB_TOKEN")
    cj_owner = env_values.get("CJ_OWNER")
    cj_repo = env_values.get("CJ_REPO")
    cj_file = env_values.get("CJ_FILE")

    if all([gh_token, cj_owner, cj_repo, cj_file]):
        logger.info("GitHub cookie storage configured - downloading cookie file...")
        try:
            validate_github_token(gh_token)
            download_cookie_from_github(gh_token, cj_owner, cj_repo, cj_file)
        except WebRequestError as e:
            e.troubleshoot()
            logger.warning("GitHub cookie download failed. Continuing with local cookies...")
    else:
        logger.info("No GitHub cookie storage configured - using local cookies only.")

    # Step 3: Verify cookies directory and file
    verify_cookies(cj_file)

    # Step 4: Start the miner
    logger.info("All pre-flight checks passed!")
    start_miner()


if __name__ == "__main__":
    main()
