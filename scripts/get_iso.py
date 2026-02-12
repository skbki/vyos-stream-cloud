#!/usr/bin/env python3
"""
Script to scrape vyos.net for the latest VyOS Stream ISO URL.
"""
import re
import sys
import requests
from urllib.parse import urljoin


def get_latest_iso_url():
    """
    Scrape VyOS.net for the latest Stream ISO URL.
    Returns the URL of the latest ISO file.
    """
    base_url = "https://vyos.net/get/nightly-builds/"
    
    try:
        # Fetch the nightly builds page
        response = requests.get(base_url, timeout=30)
        response.raise_for_status()
        
        # Look for ISO links in the page
        # Pattern matches ISO download links
        pattern = r'href="([^"]*vyos-[^"]*-amd64\.iso)"'
        matches = re.findall(pattern, response.text)
        
        if not matches:
            print("Error: No ISO files found on the page", file=sys.stderr)
            sys.exit(1)
        
        # Get the first (most recent) ISO
        iso_path = matches[0]
        
        # Construct full URL if needed
        if iso_path.startswith('http'):
            iso_url = iso_path
        else:
            iso_url = urljoin(base_url, iso_path)
        
        return iso_url
        
    except requests.RequestException as e:
        print(f"Error fetching VyOS ISO URL: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    """Main entry point."""
    iso_url = get_latest_iso_url()
    print(iso_url)


if __name__ == "__main__":
    main()
