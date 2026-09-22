/* Formulário público de envio de documentos (PROJETO-COFRE-DOCUMENTOS.md §8.7).
   A página funciona sem JavaScript; aqui só melhoramos a experiência:
   1. mostra/esconde campos e documentos condicionais (data-show-field);
   2. mostra os arquivos escolhidos e, em item de arquivo único, deixa só um;
   3. reduz fotos grandes no próprio celular (economiza dados em 3G);
   4. evita envio duplo. */
(function () {
  'use strict';

  var MAX_SIDE = 2000;
  var JPEG_QUALITY = 0.82;
  var MIN_BYTES_TO_COMPRESS = 1024 * 1024;

  function answerValues(form, field) {
    var inputs = form.querySelectorAll('[name="answers[' + field + ']"], [name="answers[' + field + '][]"]');
    var values = [];
    inputs.forEach(function (input) {
      if ((input.type === 'radio' || input.type === 'checkbox') && !input.checked) return;
      if (input.type === 'checkbox' && input.value === '1') { values.push('true'); return; }
      if (input.value) values.push(input.value);
    });
    return values;
  }

  function applyConditions(form) {
    form.querySelectorAll('[data-show-field]').forEach(function (block) {
      var visible = answerValues(form, block.dataset.showField).indexOf(block.dataset.showEquals) !== -1;
      block.hidden = !visible;
      // Campo escondido não vai no envio.
      block.querySelectorAll('input, select, textarea').forEach(function (input) { input.disabled = !visible; });
    });
  }

  function formatSize(bytes) {
    return bytes < 1024 * 1024 ? Math.max(1, Math.round(bytes / 1024)) + ' KB' : (bytes / 1048576).toFixed(1).replace('.', ',') + ' MB';
  }

  function listSelected(documentBlock) {
    var list = documentBlock.querySelector('.selected');
    if (!list) return;
    list.textContent = '';
    documentBlock.querySelectorAll('input[type="file"]').forEach(function (input) {
      Array.prototype.forEach.call(input.files || [], function (file) {
        var item = document.createElement('li');
        item.textContent = '✓ ' + file.name + ' (' + formatSize(file.size) + ')';
        list.appendChild(item);
      });
    });
  }

  function keepSingleFile(documentBlock, changedInput) {
    var inputs = documentBlock.querySelectorAll('input[type="file"]');
    var multiple = Array.prototype.some.call(inputs, function (input) { return input.multiple; });
    if (multiple) return;
    inputs.forEach(function (input) { if (input !== changedInput) input.value = ''; });
  }

  function loadImage(file) {
    return new Promise(function (resolve, reject) {
      var url = URL.createObjectURL(file);
      var image = new Image();
      image.onload = function () { URL.revokeObjectURL(url); resolve(image); };
      image.onerror = function () { URL.revokeObjectURL(url); reject(new Error('imagem')); };
      image.src = url;
    });
  }

  function compress(file) {
    if (!/^image\/(jpeg|png|webp)$/.test(file.type) || file.size < MIN_BYTES_TO_COMPRESS) return Promise.resolve(file);
    return loadImage(file).then(function (image) {
      var scale = Math.min(1, MAX_SIDE / Math.max(image.width, image.height));
      var canvas = document.createElement('canvas');
      canvas.width = Math.round(image.width * scale);
      canvas.height = Math.round(image.height * scale);
      canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
      return new Promise(function (resolve) {
        canvas.toBlob(function (blob) {
          if (!blob || blob.size >= file.size) { resolve(file); return; }
          resolve(new File([blob], file.name.replace(/\.\w+$/, '') + '.jpg', { type: 'image/jpeg' }));
        }, 'image/jpeg', JPEG_QUALITY);
      });
    }).catch(function () { return file; });
  }

  function compressInput(input) {
    if (!window.DataTransfer || !input.files || !input.files.length) return Promise.resolve();
    return Promise.all(Array.prototype.map.call(input.files, compress)).then(function (files) {
      var transfer = new DataTransfer();
      files.forEach(function (file) { transfer.items.add(file); });
      input.files = transfer.files;
    }).catch(function () { /* mantém os arquivos originais */ });
  }

  function init() {
    var form = document.getElementById('document-form');
    if (!form) return;

    applyConditions(form);
    form.addEventListener('change', function (event) {
      var target = event.target;
      if (target.name && target.name.indexOf('answers[') === 0) applyConditions(form);
      if (target.type !== 'file') return;
      var block = target.closest('.document');
      keepSingleFile(block, target);
      var pending = target.hasAttribute('data-compress') ? compressInput(target) : Promise.resolve();
      pending.then(function () { listSelected(block); });
    });

    form.addEventListener('submit', function () {
      var button = form.querySelector('[data-submit]');
      if (!button) return;
      button.disabled = true;
      button.textContent = 'Enviando…';
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
