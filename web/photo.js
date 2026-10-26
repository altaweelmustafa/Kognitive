// Profile photos in the web app (lib/data/photo_picker_web.dart calls this).
// Safari decodes the photo itself, HEIC included, and it's cropped and shrunk
// here, so the app only ever gets a small square JPEG.
(function () {
  async function decode(file) {
    if ('createImageBitmap' in window) {
      try { return await createImageBitmap(file); } catch (_) { /* fall back */ }
    }
    const url = URL.createObjectURL(file);
    try {
      const img = new Image();
      img.src = url;
      await img.decode();
      return img;
    } finally {
      URL.revokeObjectURL(url);
    }
  }

  async function square(file, size) {
    const img = await decode(file);
    const w = img.naturalWidth || img.width;
    const h = img.naturalHeight || img.height;
    if (!w || !h) throw new Error('empty image');
    const side = Math.min(w, h);
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(img, (w - side) / 2, (h - side) / 2, side, side, 0, 0, size, size);
    if (img.close) img.close();
    return canvas.toDataURL('image/jpeg', 0.9).split(',')[1];
  }

  window.kognitivPhoto = {
    // Opens the photo picker (call straight from a tap) and resolves to the
    // chosen photo as a base64 square JPEG, or '' if nothing was chosen.
    pick: (size) => new Promise((resolve, reject) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.style.display = 'none';
      document.body.appendChild(input);
      let done = false;
      const finish = (settle, value) => {
        if (done) return;
        done = true;
        input.remove();
        settle(value);
      };
      input.addEventListener('change', async () => {
        const file = input.files && input.files[0];
        if (!file) return finish(resolve, '');
        try {
          finish(resolve, await square(file, size));
        } catch (e) {
          finish(reject, new Error('Safari could not read that photo (' + (e && e.message || e) + ')'));
        }
      });
      input.addEventListener('cancel', () => finish(resolve, ''));
      input.click();
    }),
  };
})();
