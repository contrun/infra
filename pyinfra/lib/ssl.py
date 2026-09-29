import os


def setup_ssl_cert() -> None:
    """Ensure SSL_CERT_FILE is set for environments like Nix or standalone Python."""
    if "SSL_CERT_FILE" not in os.environ:
        try:
            import certifi

            os.environ["SSL_CERT_FILE"] = certifi.where()
        except ImportError:
            pass
