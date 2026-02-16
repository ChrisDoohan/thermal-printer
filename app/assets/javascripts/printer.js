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

