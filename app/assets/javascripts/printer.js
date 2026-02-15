// Generate twinkling 8-bit stars
(function() {
  var starfield = document.getElementById('starfield');
  for (var i = 0; i < 120; i++) {
    var star = document.createElement('div');
    star.className = 'star';
    var size = Math.random() < 0.85 ? 2 : 3;
    star.style.width = size + 'px';
    star.style.height = size + 'px';
    star.style.left = Math.random() * 100 + '%';
    star.style.top = Math.random() * 100 + '%';
    star.style.setProperty('--duration', (1.5 + Math.random() * 3) + 's');
    star.style.setProperty('--delay', (Math.random() * 4) + 's');
    starfield.appendChild(star);
  }
})();

var quill = new Quill('#editor', {
  theme: 'snow',
  modules: {
    toolbar: {
      container: [
        ['bold', 'italic', 'underline', 'invert'],
        [{ 'header': [1, 2, 3, false] }],
        [{ 'align': ['', 'center', 'right'] }]
      ],
      handlers: {
        'invert': function() {
          var range = this.quill.getSelection();
          if (!range) return;
          var format = this.quill.getFormat(range);
          if (format.background) {
            this.quill.format('background', false);
          } else {
            this.quill.format('background', '#ffffff');
          }
        }
      }
    }
  }
});

// Label the custom invert button
var invertBtn = document.querySelector('.ql-invert');
invertBtn.innerHTML = 'INV';
invertBtn.title = 'Invert (highlight)';

function showToast(message, type) {
  var toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = 'toast ' + type + ' show';
  setTimeout(function() { toast.className = 'toast'; }, 1000);
}

function submitPrint(commit) {
  var html = quill.root.innerHTML;
  var token = document.querySelector('meta[name="csrf-token"]').content;
  var printUrl = document.getElementById('printer-config').dataset.printUrl;

  fetch(printUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
    body: JSON.stringify({ html: html, commit: commit })
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.error) {
      showToast(data.error, 'error');
    } else {
      showToast(data.message, 'success');
    }
  })
  .catch(function() { showToast('Request failed', 'error'); });
}

function submitCut() {
  var token = document.querySelector('meta[name="csrf-token"]').content;
  var cutUrl = document.getElementById('printer-config').dataset.cutUrl;

  fetch(cutUrl, {
    method: 'POST',
    headers: { 'X-CSRF-Token': token }
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.error) {
      showToast(data.error, 'error');
    } else {
      showToast(data.message, 'success');
    }
  })
  .catch(function() { showToast('Request failed', 'error'); });
}

function checkStatus() {
  fetch('/status')
    .then(function(response) { return response.json(); })
    .then(function(data) {
      var statusEl = document.getElementById('printer-status');
      var textEl = statusEl.querySelector('.status-text');

      if (data.connected) {
        statusEl.className = 'status connected';
        textEl.textContent = 'Printer connected';
      } else {
        statusEl.className = 'status disconnected';
        textEl.textContent = 'Printer not found';
      }
    })
    .catch(function() {
      var statusEl = document.getElementById('printer-status');
      var textEl = statusEl.querySelector('.status-text');
      statusEl.className = 'status disconnected';
      textEl.textContent = 'Unable to check status';
    });
}

setInterval(checkStatus, 5000);
