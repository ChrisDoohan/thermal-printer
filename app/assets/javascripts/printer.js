// Guard against Turbo re-initialization
if (document.querySelector('.ql-toolbar')) {
  var quill = document.querySelector('#editor').__quill;
} else {

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

} // end Turbo guard

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
    body: JSON.stringify({ html: html, commit: commit, username: localStorage.getItem('username') || 'anonymous' })
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.error) {
      showToast(data.error, 'error');
    } else {
      showToast(data.message, 'success');
      if (data.entry) prependHistoryEntry(data.entry);
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

// =========================================================
// Print History
// =========================================================

function timeAgo(dateString) {
  var seconds = Math.floor((new Date() - new Date(dateString)) / 1000);
  if (seconds < 60) return 'just now';
  var minutes = Math.floor(seconds / 60);
  if (minutes < 60) return minutes + 'm ago';
  var hours = Math.floor(minutes / 60);
  if (hours < 24) return hours + 'h ago';
  var days = Math.floor(hours / 24);
  if (days < 30) return days + 'd ago';
  return new Date(dateString).toLocaleDateString();
}

function buildHistoryEntry(entry) {
  var el = document.createElement('div');
  el.className = 'history-entry';
  el.dataset.contentId = entry.id;
  el.dataset.searchText = ((entry.preview || '') + ' ' + entry.username).toLowerCase();

  var meta = document.createElement('div');
  meta.className = 'history-meta';
  meta.innerHTML = '<span class="history-user">' + escapeHtml(entry.username) + '</span>' +
    '<span class="history-time">' + timeAgo(entry.printed_at) + '</span>';
  el.appendChild(meta);

  var preview = document.createElement('div');
  preview.className = 'history-preview';

  if (entry.content_type === 'image' && entry.thumbnail) {
    var img = document.createElement('img');
    img.src = 'data:image/png;base64,' + entry.thumbnail;
    img.className = 'history-thumbnail';
    preview.appendChild(img);
  } else if (entry.preview) {
    preview.textContent = entry.preview;
  }
  el.appendChild(preview);

  // Expanded content (hidden by default)
  var expanded = document.createElement('div');
  expanded.className = 'history-expanded';
  if (entry.content_type === 'text' && entry.body) {
    expanded.innerHTML = entry.body;
  }
  el.appendChild(expanded);

  el.addEventListener('click', function() {
    el.classList.toggle('open');
  });

  return el;
}

function escapeHtml(str) {
  var div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function prependHistoryEntry(entry) {
  var list = document.getElementById('history-list');
  if (!list) return;

  // Remove existing entry for same content (reprint bumps to top)
  var existing = list.querySelector('[data-content-id="' + entry.id + '"]');
  if (existing) existing.remove();

  var el = buildHistoryEntry(entry);
  list.insertBefore(el, list.firstChild);

  // Update empty state
  var empty = list.querySelector('.history-empty');
  if (empty) empty.remove();
}

function loadHistory() {
  var list = document.getElementById('history-list');
  if (!list) return;

  fetch('/prints')
    .then(function(r) { return r.json(); })
    .then(function(entries) {
      list.innerHTML = '';
      if (entries.length === 0) {
        list.innerHTML = '<div class="history-empty">Nothing printed yet</div>';
        return;
      }
      entries.forEach(function(entry) {
        list.appendChild(buildHistoryEntry(entry));
      });
    })
    .catch(function() {
      list.innerHTML = '<div class="history-empty">Could not load history</div>';
    });
}

// Search filtering
(function() {
  var searchInput = document.getElementById('history-search');
  if (!searchInput) return;

  searchInput.addEventListener('input', function() {
    var query = this.value.toLowerCase().trim();
    var entries = document.querySelectorAll('.history-entry');
    entries.forEach(function(el) {
      if (!query || el.dataset.searchText.indexOf(query) !== -1) {
        el.style.display = '';
      } else {
        el.style.display = 'none';
      }
    });
  });
})();

// Load history on page load
loadHistory();
