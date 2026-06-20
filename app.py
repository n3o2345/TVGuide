from flask import Flask, render_template, request, redirect, url_for, send_from_directory, Response
from markupsafe import Markup
import gzip
import json
import os
import subprocess
import threading
import time

CONFIG_FILE = "/config/settings.json"
DEFAULT_OUTPUT_DIR = "/output"

app = Flask(__name__, template_folder='/app/templates', static_folder='/app/static')

# ── Config helpers ────────────────────────────────────────

def load_cfg():
    if not os.path.exists(CONFIG_FILE):
        default_cfg = {
            'lineups': '', 'zipcodes': [], 'country': 'USA',
            'timespan': '72', 'verbose': '1',
            'output_dir': '/output', 'http_port': '8282', 'webui_port': '5000'
        }
        save_cfg(default_cfg)
        return default_cfg
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config: {e}")
        return {}

def save_cfg(cfg):
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        print(f"Error saving config: {e}")

def get_output_dir():
    return load_cfg().get('output_dir', DEFAULT_OUTPUT_DIR).rstrip('/')

def get_xml_path():
    return os.path.join(get_output_dir(), 'xmltv.xml')

def get_log_dir():
    return os.path.join(get_output_dir(), 'logs')

# ── Utilities ─────────────────────────────────────────────

def tail_log(file_path, lines=200):
    if not os.path.exists(file_path):
        return ""
    try:
        with open(file_path, "rb") as f:
            f.seek(0, 2)
            file_size = f.tell()
            block_size = 1024
            data = b''
            while file_size > 0 and lines > 0:
                step = min(block_size, file_size)
                f.seek(file_size - step)
                chunk = f.read(step)
                data = chunk + data
                lines -= chunk.count(b'\n')
                file_size -= step
            return data.decode(errors='replace')[-20000:]
    except Exception as e:
        print(f"Error reading log: {e}")
        return ""

def run_in_background(cmd):
    log_dir = get_log_dir()
    os.makedirs(log_dir, exist_ok=True)
    p = subprocess.Popen(
        cmd, shell=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        bufsize=1, universal_newlines=True
    )
    latest = os.path.join(log_dir, "latest.log")

    def reader():
        try:
            with open(latest, "a") as out:
                for line in p.stdout:
                    out.write(line)
                    out.flush()
        except Exception as e:
            print(f"Error writing log: {e}")

    threading.Thread(target=reader, daemon=True).start()
    return p

# ── XMLTV serving ─────────────────────────────────────────

def _serve_xml(use_gzip=False):
    xml_path = get_xml_path()
    if not os.path.exists(xml_path):
        return "No epg.xml yet — run the EPG grabber first.", 404

    if use_gzip:
        with open(xml_path, "rb") as f:
            gz_bytes = gzip.compress(f.read())
        return Response(
            gz_bytes, status=200, mimetype="application/gzip",
            headers={
                "Content-Disposition": "attachment; filename=epg.xml.gz",
                "Content-Length": str(len(gz_bytes)),
            }
        )
    return send_from_directory(
        os.path.dirname(xml_path), os.path.basename(xml_path),
        mimetype="text/xml"
    )

@app.route("/epg.xml")
@app.route("/xmltv")
def epg_xml():
    """Serve XMLTV as plain XML or gzip.
    ?output=gz  or  Accept-Encoding: gzip  → compressed
    ?output=xml                             → plain XML (override)
    """
    param = request.args.get("output", "").lower()
    accept = request.headers.get("Accept-Encoding", "")
    use_gzip = (param == "gz") or (param != "xml" and "gzip" in accept)
    return _serve_xml(use_gzip)

@app.route("/epg.xml.gz")
@app.route("/xmltv.gz")
def epg_xml_gz():
    """Always serve gzip-compressed XMLTV."""
    return _serve_xml(use_gzip=True)

# ── Static / misc ─────────────────────────────────────────

@app.route("/logo")
def logo():
    return send_from_directory('/app/static', 'tvguide.png', mimetype='image/png')

@app.after_request
def add_no_cache_headers(response):
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    return response

# ── Routes ────────────────────────────────────────────────

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        cfg = load_cfg()
        cfg['lineups']    = request.form.get('lineups', '').strip()
        cfg['zipcodes']   = request.form.get('zipcodes', '').strip()
        cfg['country']    = request.form.get('country', 'USA').strip()
        cfg['timespan']   = request.form.get('timespan', '72').strip()
        cfg['verbose']    = request.form.get('verbose', '1').strip()
        cfg['output_dir'] = request.form.get('output_dir', '/output').strip()
        cfg['http_port']  = request.form.get('http_port', '8282').strip()
        cfg['webui_port'] = request.form.get('webui_port', '5000').strip()
        print(f"Config saved: lineups={cfg.get('lineups')}, zipcodes={cfg.get('zipcodes')}")
        save_cfg(cfg)
        return redirect(url_for('index'))

    cfg = load_cfg()

    zipcodes_data = cfg.get('zipcodes', [])
    if isinstance(zipcodes_data, str):
        zipcodes_data = [{'zip': z.strip(), 'provider': ''} for z in zipcodes_data.split(',') if z.strip()]
    elif not isinstance(zipcodes_data, list):
        zipcodes_data = []
    cfg['zipcodes_json'] = json.dumps(zipcodes_data)

    lineups_data = cfg.get('lineups', '')
    if isinstance(lineups_data, list):
        lineups_data = ', '.join(lineups_data)
    cfg['lineups_json'] = json.dumps([l.strip() for l in str(lineups_data).split(',') if l.strip()])

    latest_log = ""
    latest_log_path = os.path.join(get_log_dir(), "latest.log")
    if os.path.exists(latest_log_path):
        latest_log = tail_log(latest_log_path, lines=500)

    xml_path = get_xml_path()
    xml_info = {}
    if os.path.exists(xml_path):
        xml_info['size']  = os.path.getsize(xml_path)
        xml_info['mtime'] = time.ctime(os.path.getmtime(xml_path))

    return render_template("index.html", cfg=cfg, latest_log=latest_log, xml_info=xml_info)

@app.route("/run", methods=["POST"])
def run_now():
    run_in_background("/app/run-multi.sh")
    return redirect(url_for('index'))

@app.route("/logs")
def logs():
    latest_log_path = os.path.join(get_log_dir(), "latest.log")
    content = ""
    if os.path.exists(latest_log_path):
        try:
            with open(latest_log_path, "r", errors='replace') as f:
                content = f.read()
        except Exception as e:
            content = f"Error reading logs: {e}"
    return "<pre>" + Markup.escape(content) + "</pre>"

if __name__ == "__main__":
    app.config['TEMPLATES_AUTO_RELOAD'] = True
    app.run(host="0.0.0.0", port=int(os.environ.get('WEBUI_PORT', '5000')), debug=False)
