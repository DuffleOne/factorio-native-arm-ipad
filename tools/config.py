"""Machine-local settings; only the example belongs in version control."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / '.local-config.json'
SETTINGS = json.loads(CONFIG_PATH.read_text()) if CONFIG_PATH.exists() else {}
DEFAULT_APP = Path(os.environ.get('FACTORIO_APP') or SETTINGS.get('factorio_app') or
                   Path.home() / 'Library/Application Support/Steam/steamapps/common/Factorio/factorio.app').expanduser()
CMAKE = os.environ.get('FACTORIO_CMAKE') or SETTINGS.get('cmake') or 'cmake'
DEFAULT_BUNDLE_ID = 'local.factorio.loaderprobe'
SUPPORTED_SHA256 = '00b014d78df07e05ab1cee853904c8f7b3814ca652c043461a9d49fbad46cdf6'

def validate_source(app):
    import hashlib
    binary = app / 'Contents/MacOS/factorio'
    if not binary.is_file():
        raise ValueError(f'Factorio executable not found: {binary}. Run tools/setup.py --app /path/to/factorio.app')
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    if digest != SUPPORTED_SHA256:
        raise ValueError(f'Unsupported Factorio executable SHA-256: {digest}\n'
                         f'Required: {SUPPORTED_SHA256} (2.0.77, build 84539, macOS Steam universal binary).\n'
                         'Do not bypass this check: the patches are specific to this executable.')
    for relative in ('Contents/Info.plist', 'Contents/data/base/info.json', 'Contents/data/core/info.json'):
        if not (app / relative).is_file():
            raise ValueError(f'Incomplete Factorio app: missing {relative}')
    return digest
