// === Image Editor for Thermal Printer ===

(function() {
  var PRINTER_WIDTH = 512;

  // --- State ---
  var originalDataUrl = null;  // Original loaded image (for re-crop)
  var cropperInstance = null;
  var grayscaleBase = null;    // Float32Array, grayscale at 512px wide
  var baseWidth = 0;
  var baseHeight = 0;
  var rotation = 0;
  var invertOn = false;
  var ditherMode = 'floyd-steinberg';

  // --- DOM refs ---
  var dropZone = document.getElementById('drop-zone');
  var fileInput = document.getElementById('file-input');
  var cropSection = document.getElementById('crop-section');
  var cropImage = document.getElementById('crop-image');
  var processSection = document.getElementById('process-section');
  var previewCanvas = document.getElementById('preview-canvas');
  var contrastSlider = document.getElementById('contrast');
  var whitepointSlider = document.getElementById('whitepoint');
  var contrastVal = document.getElementById('contrast-val');
  var whitepointVal = document.getElementById('whitepoint-val');
  var invertBtn = document.getElementById('btn-invert');

  // --- Starfield (same as printer page) ---
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

  // =========================================================
  // Phase 2: Image Input
  // =========================================================

  // File picker
  fileInput.addEventListener('change', function(e) {
    if (e.target.files[0]) loadImage(e.target.files[0]);
  });

  // Clicking the drop zone triggers file picker
  dropZone.addEventListener('click', function(e) {
    if (e.target === fileInput || e.target.tagName === 'LABEL') return;
    fileInput.click();
  });

  // Drag and drop
  dropZone.addEventListener('dragover', function(e) {
    e.preventDefault();
    dropZone.classList.add('drag-over');
  });
  dropZone.addEventListener('dragleave', function() {
    dropZone.classList.remove('drag-over');
  });
  dropZone.addEventListener('drop', function(e) {
    e.preventDefault();
    dropZone.classList.remove('drag-over');
    if (e.dataTransfer.files[0]) loadImage(e.dataTransfer.files[0]);
  });

  // Clipboard paste
  document.addEventListener('paste', function(e) {
    var items = e.clipboardData.items;
    for (var i = 0; i < items.length; i++) {
      if (items[i].type.indexOf('image') !== -1) {
        loadImage(items[i].getAsFile());
        return;
      }
    }
  });

  function loadImage(file) {
    var reader = new FileReader();
    reader.onload = function(e) {
      originalDataUrl = e.target.result;
      showCropSection(originalDataUrl);
    };
    reader.readAsDataURL(file);
  }

  // =========================================================
  // Phase 3: Cropping
  // =========================================================

  function showCropSection(dataUrl) {
    dropZone.style.display = 'none';
    processSection.style.display = 'none';
    cropSection.style.display = 'block';

    cropImage.src = dataUrl;

    if (cropperInstance) cropperInstance.destroy();
    cropperInstance = new Cropper(cropImage, {
      viewMode: 1,
      autoCropArea: 1,
      responsive: true,
      background: false
    });
  }

  document.getElementById('btn-crop-apply').addEventListener('click', function() {
    var croppedCanvas = cropperInstance.getCroppedCanvas();
    cropperInstance.destroy();
    cropperInstance = null;
    enterProcessing(croppedCanvas);
  });

  document.getElementById('btn-crop-skip').addEventListener('click', function() {
    if (cropperInstance) {
      cropperInstance.destroy();
      cropperInstance = null;
    }
    var img = new Image();
    img.onload = function() {
      var c = document.createElement('canvas');
      c.width = img.naturalWidth;
      c.height = img.naturalHeight;
      c.getContext('2d').drawImage(img, 0, 0);
      enterProcessing(c);
    };
    img.src = originalDataUrl;
  });

  document.getElementById('btn-crop-cancel').addEventListener('click', function() {
    resetToDropZone();
  });

  document.getElementById('btn-back').addEventListener('click', function() {
    resetToDropZone();
  });

  document.getElementById('btn-recrop').addEventListener('click', function() {
    resetControls();
    showCropSection(originalDataUrl);
  });

  function resetToDropZone() {
    cropSection.style.display = 'none';
    processSection.style.display = 'none';
    dropZone.style.display = 'block';
    if (cropperInstance) {
      cropperInstance.destroy();
      cropperInstance = null;
    }
    originalDataUrl = null;
    fileInput.value = '';
    resetControls();
  }

  function resetControls() {
    contrastSlider.value = 0;
    whitepointSlider.value = 0;
    contrastVal.textContent = '0';
    whitepointVal.textContent = '0';
    rotation = 0;
    invertOn = false;
    ditherMode = 'floyd-steinberg';
    invertBtn.classList.remove('active');

    var rotBtns = document.querySelectorAll('.rotation-btn');
    rotBtns.forEach(function(b) { b.classList.remove('active'); });
    rotBtns[0].classList.add('active');

    var modeBtns = document.querySelectorAll('.mode-btn');
    modeBtns.forEach(function(b) { b.classList.remove('active'); });
    document.querySelector('.mode-btn[data-mode="floyd-steinberg"]').classList.add('active');
  }

  // =========================================================
  // Phase 4: Processing Pipeline
  // =========================================================

  var sourceCanvas = null;  // The cropped input canvas (full color, original size)

  function enterProcessing(inputCanvas) {
    sourceCanvas = inputCanvas;
    cropSection.style.display = 'none';
    processSection.style.display = 'block';
    rebuildGrayscale();
    runPipeline();
  }

  function rebuildGrayscale() {
    var rotated = applyRotation(sourceCanvas, rotation);

    // Scale to printer width
    var scale = PRINTER_WIDTH / rotated.width;
    var w = PRINTER_WIDTH;
    var h = Math.round(rotated.height * scale);

    var temp = document.createElement('canvas');
    temp.width = w;
    temp.height = h;
    temp.getContext('2d').drawImage(rotated, 0, 0, w, h);

    var imageData = temp.getContext('2d').getImageData(0, 0, w, h);
    var data = imageData.data;

    // Convert to grayscale
    var gray = new Float32Array(w * h);
    for (var i = 0; i < gray.length; i++) {
      gray[i] = 0.299 * data[i * 4] + 0.587 * data[i * 4 + 1] + 0.114 * data[i * 4 + 2];
    }

    grayscaleBase = gray;
    baseWidth = w;
    baseHeight = h;
  }

  function applyRotation(srcCanvas, degrees) {
    if (degrees === 0) return srcCanvas;
    var c = document.createElement('canvas');
    var ctx = c.getContext('2d');
    if (degrees === 90 || degrees === 270) {
      c.width = srcCanvas.height;
      c.height = srcCanvas.width;
    } else {
      c.width = srcCanvas.width;
      c.height = srcCanvas.height;
    }
    ctx.translate(c.width / 2, c.height / 2);
    ctx.rotate(degrees * Math.PI / 180);
    ctx.drawImage(srcCanvas, -srcCanvas.width / 2, -srcCanvas.height / 2);
    return c;
  }

  function runPipeline() {
    var w = baseWidth;
    var h = baseHeight;
    var pixels = new Float32Array(grayscaleBase);

    // 1. Contrast
    var contrast = parseInt(contrastSlider.value);
    if (contrast !== 0) {
      var factor = (259 * (contrast + 255)) / (255 * (259 - contrast));
      for (var i = 0; i < pixels.length; i++) {
        pixels[i] = factor * (pixels[i] - 128) + 128;
      }
    }

    // 2. White point offset
    var wp = parseInt(whitepointSlider.value);
    if (wp !== 0) {
      for (var i = 0; i < pixels.length; i++) {
        pixels[i] = pixels[i] + wp;
      }
    }

    // 3. Clamp to 0-255
    for (var i = 0; i < pixels.length; i++) {
      if (pixels[i] < 0) pixels[i] = 0;
      else if (pixels[i] > 255) pixels[i] = 255;
    }

    // 4. Invert
    if (invertOn) {
      for (var i = 0; i < pixels.length; i++) {
        pixels[i] = 255 - pixels[i];
      }
    }

    // 5. Dither / threshold
    var output;
    if (ditherMode === 'threshold') {
      output = thresholdConvert(pixels, 128);
    } else if (ditherMode === 'floyd-steinberg') {
      output = floydSteinberg(pixels, w, h);
    } else {
      output = atkinsonDither(pixels, w, h);
    }

    // 6. Render
    renderOutput(output, w, h);
  }

  function thresholdConvert(pixels, threshold) {
    var out = new Uint8Array(pixels.length);
    for (var i = 0; i < pixels.length; i++) {
      out[i] = pixels[i] < threshold ? 0 : 255;
    }
    return out;
  }

  function floydSteinberg(pixels, w, h) {
    var out = new Uint8Array(pixels.length);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var idx = y * w + x;
        var old = pixels[idx];
        var val = old < 128 ? 0 : 255;
        out[idx] = val;
        var err = old - val;
        if (x + 1 < w)               pixels[idx + 1]     += err * 7 / 16;
        if (y + 1 < h && x - 1 >= 0) pixels[idx + w - 1] += err * 3 / 16;
        if (y + 1 < h)               pixels[idx + w]     += err * 5 / 16;
        if (y + 1 < h && x + 1 < w)  pixels[idx + w + 1] += err * 1 / 16;
      }
    }
    return out;
  }

  function atkinsonDither(pixels, w, h) {
    var out = new Uint8Array(pixels.length);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var idx = y * w + x;
        var old = pixels[idx];
        var val = old < 128 ? 0 : 255;
        out[idx] = val;
        var err = (old - val) / 8;
        if (x + 1 < w)               pixels[idx + 1]     += err;
        if (x + 2 < w)               pixels[idx + 2]     += err;
        if (y + 1 < h && x - 1 >= 0) pixels[idx + w - 1] += err;
        if (y + 1 < h)               pixels[idx + w]     += err;
        if (y + 1 < h && x + 1 < w)  pixels[idx + w + 1] += err;
        if (y + 2 < h)               pixels[idx + 2 * w] += err;
      }
    }
    return out;
  }

  function renderOutput(output, w, h) {
    previewCanvas.width = w;
    previewCanvas.height = h;
    var ctx = previewCanvas.getContext('2d');
    var imageData = ctx.createImageData(w, h);
    var data = imageData.data;

    for (var i = 0; i < output.length; i++) {
      var v = output[i];
      data[i * 4]     = v;
      data[i * 4 + 1] = v;
      data[i * 4 + 2] = v;
      data[i * 4 + 3] = 255;
    }

    ctx.putImageData(imageData, 0, 0);
  }

  // =========================================================
  // Event Bindings
  // =========================================================

  // Sliders — real-time update on input
  contrastSlider.addEventListener('input', function() {
    contrastVal.textContent = this.value;
    runPipeline();
  });

  whitepointSlider.addEventListener('input', function() {
    whitepointVal.textContent = this.value;
    runPipeline();
  });

  // Rotation buttons
  document.querySelectorAll('.rotation-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      document.querySelectorAll('.rotation-btn').forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      rotation = parseInt(btn.dataset.rotation);
      rebuildGrayscale();
      runPipeline();
    });
  });

  // Invert toggle
  invertBtn.addEventListener('click', function() {
    invertOn = !invertOn;
    invertBtn.classList.toggle('active');
    runPipeline();
  });

  // Dither mode buttons
  document.querySelectorAll('.mode-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      document.querySelectorAll('.mode-btn').forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
      ditherMode = btn.dataset.mode;
      runPipeline();
    });
  });

  // =========================================================
  // Printing
  // =========================================================

  function showToast(message, type) {
    var toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = 'toast ' + type + ' show';
    setTimeout(function() { toast.className = 'toast'; }, 1000);
  }

  function sendPrint(cut) {
    var dataUrl = previewCanvas.toDataURL('image/png');
    var token = document.querySelector('meta[name="csrf-token"]').content;
    var printUrl = document.getElementById('editor-config').dataset.printUrl;

    fetch(printUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
      body: JSON.stringify({ image: dataUrl, cut: cut ? 'true' : 'false' })
    })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.error) showToast(data.error, 'error');
      else showToast(data.message, 'success');
    })
    .catch(function() { showToast('Request failed', 'error'); });
  }

  document.getElementById('btn-print').addEventListener('click', function() { sendPrint(false); });
  document.getElementById('btn-print-cut').addEventListener('click', function() { sendPrint(true); });
})();
