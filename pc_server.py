from flask import Flask, jsonify, abort, request
import io, base64, tempfile, os
from flask_cors import CORS
import zstandard as zstd
from PIL import ImageGrab
import win32clipboard
from windows_toasts import InteractableWindowsToaster, Toast, ToastDisplayImage, ToastButton, ToastImagePosition
import threading

app = Flask(__name__)
CORS(app)

# Zstd compressor at maximum level (22)
compressor = zstd.ZstdCompressor(level=22)
# Interactable Windows Toasts (supports images and buttons)
toaster = InteractableWindowsToaster("Lily")


def save_image(data_b64, suffix):
    """Decode a base64 string to a temporary file and return its path."""
    raw = base64.b64decode(data_b64)
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    tmp.write(raw)
    tmp.close()
    return tmp.name


def get_clipboard_content():
    """
    Returns a dict with:
      - 'mime': MIME type of clipboard data
      - 'data': text or base64 string for images
    """
    img = ImageGrab.grabclipboard()
    if img:
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return {'mime': 'image/png', 'data': base64.b64encode(buf.getvalue()).decode('ascii')}
    win32clipboard.OpenClipboard()
    try:
        if win32clipboard.IsClipboardFormatAvailable(win32clipboard.CF_UNICODETEXT):
            txt = win32clipboard.GetClipboardData(win32clipboard.CF_UNICODETEXT)
            return {'mime': 'text/plain; charset=utf-8', 'data': txt}
        return {'mime': None, 'data': None}
    finally:
        win32clipboard.CloseClipboard()

@app.after_request
def compress_response(response):
    if response.content_type == 'application/json' and response.status_code == 200:
        if 'zstd' in request.headers.get('Accept-Encoding', ''):
            raw = response.get_data()
            comp = compressor.compress(raw)
            response.set_data(comp)
            response.headers['Content-Encoding'] = 'zstd'
            response.headers['Content-Length'] = str(len(comp))
    return response

@app.route("/")
def home():
    return jsonify({"message": "Clipboard API with Zstd & rich interactive notifications"})

@app.route('/clipboard', methods=['GET'])
def clipboard_route():
    content = get_clipboard_content()
    if content['data'] is None:
        return abort(204)
    return jsonify(content)

@app.route('/notify', methods=['POST'])
def notify_route():
    data = request.get_json(force=True)
    type_ = data.get('type')
    if type_ not in ('calls', 'messages', 'notifs'):
        abort(400, description="Invalid notification type")

    # Common fields
    logo_b64 = data.get('logo')  # JPG
    image_b64 = data.get('image')  # PNG/JPG
    content = data.get('content', '')
    name = data.get('name')
    number = data.get('number')

    # Save images
    icon_path = save_image(logo_b64, suffix='.jpg') if logo_b64 else None
    hero_path = save_image(image_b64, suffix='.png') if image_b64 else None

    # Determine text lines and buttons
    lines = []
    actions = []
    if type_ == 'calls':
        if not name or not number:
            abort(400, description="'name' and 'number' required for calls")
        lines = [f"Incoming call from {name}", number]
        actions = [("Answer", "action=answer"), ("Decline", "action=decline")]
    elif type_ == 'messages':
        lines = [content]
        actions = [("Reply", "action=reply"), ("Mark as Read", "action=markread")]
    else:  # notifs
        lines = [content]

    # Build toast
    toast = Toast(lines)
    if icon_path:
        toast.AddImage(ToastDisplayImage.fromPath(icon_path, position=ToastImagePosition.AppLogo))
    if hero_path:
        toast.AddImage(ToastDisplayImage.fromPath(hero_path, position=ToastImagePosition.Hero))
    for label, arg in actions:
        toast.AddAction(ToastButton(label, arg))

    # Prepare event and callback for user action
    action_event = threading.Event()
    selected_arg = {'value': None}
    def on_activated(evt_args):
        selected_arg['value'] = getattr(evt_args, 'arguments', None)
        action_event.set()
    toast.on_activated = on_activated

    # Show toast and wait for user action or timeout
    toaster.show_toast(toast)
    if actions:
        # wait up to 8 seconds (adjust as needed)
        if action_event.wait(timeout=8):
            return jsonify({'status': 'action', 'action': selected_arg['value']}), 200
        else:
            return jsonify({'status': 'timeout'}), 200
    else:
        # non-interactive notification
        return jsonify({'status': 'shown'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
