let isDragging  = false;
let dragOffsetX = 0;
let dragOffsetY = 0;
let selectedType = null;

const dragHandle = document.getElementById('dragHandle');

dragHandle.addEventListener('mousedown', function(e) {
    isDragging = true;
    const container = document.getElementById('radarUI');
    const rect = container.getBoundingClientRect();
    dragOffsetX = e.clientX - rect.left;
    dragOffsetY = e.clientY - rect.top;
    container.style.transition = 'none';
    e.preventDefault();
});

document.addEventListener('mousemove', function(e) {
    if (!isDragging) return;
    const container = document.getElementById('radarUI');
    container.style.left  = (e.clientX - dragOffsetX) + 'px';
    container.style.top   = (e.clientY - dragOffsetY) + 'px';
    container.style.transform = 'none';
});

document.addEventListener('mouseup', function() { isDragging = false; });

/* ── MENSAGENS DO CLIENT ── */
window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'showList') {
        document.getElementById('listView').style.display   = 'block';
        document.getElementById('creatorView').style.display = 'none';
        document.getElementById('typeSelector').classList.remove('show');
        selectedType = null;

        // Reseta seleção de botões
        document.querySelectorAll('.type-btn').forEach(b => b.classList.remove('sel'));

        const list = document.getElementById('radarList');
        if (data.radars && data.radars.length > 0) {
            list.innerHTML = data.radars.map(r => `
                <div class="radar-item">
                    <div>
                        <div class="r-id">#${r.id}</div>
                        <div class="r-name">${r.speedName} — ${r.speedLimit} km/h</div>
                        <div class="r-coord">X ${r.x.toFixed(0)} &nbsp;Y ${r.y.toFixed(0)}</div>
                    </div>
                    <button class="btn-del" onclick="deleteRadar(${r.id})">Excluir</button>
                </div>
            `).join('');
        } else {
            list.innerHTML = '<div class="empty">Nenhum radar criado</div>';
        }

        const container = document.getElementById('radarUI');
        container.classList.add('active');
        container.style.left      = '50%';
        container.style.top       = '50%';
        container.style.transform = 'translate(-50%, -50%)';
    }

    if (data.action === 'showCreator') {
        document.getElementById('listView').style.display    = 'none';
        document.getElementById('creatorView').style.display = 'block';
        document.getElementById('radarUI').classList.add('active');

        const badge       = document.getElementById('stageBadge');
        const zoneSection = document.getElementById('zoneSection');

        if (data.stage === 2) {
            badge.innerHTML   = '<span class="stage-dot"></span> Etapa 2 — Zona de detecção';
            badge.className   = 'stage-badge s2';
            zoneSection.classList.add('show');
        } else {
            badge.innerHTML   = '<span class="stage-dot"></span> Etapa 1 — Posicionar placa';
            badge.className   = 'stage-badge s1';
            zoneSection.classList.remove('show');
        }
    }

    if (data.action === 'close') {
        document.getElementById('radarUI').classList.remove('active');
        selectedType = null;
    }
});

/* ── SELETOR DE TIPO ── */
function showTypeSelector() {
    document.getElementById('typeSelector').classList.toggle('show');
}

function selectType(speedType) {
    selectedType = speedType;

    document.querySelectorAll('.type-btn').forEach(b => b.classList.remove('sel'));
    const btn = document.getElementById('tbtn' + speedType);
    if (btn) btn.classList.add('sel');

    fetch('https://sradar/selectType', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ speedType: speedType, speedLimit: speedType })
    });
}

/* ── CONTROLES DE POSIÇÃO ── */
function move(direction) {
    fetch('https://sradar/move', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ direction: direction })
    });
}

function rotate(direction) {
    fetch('https://sradar/rotate', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ direction: direction })
    });
}

/* ── TAMANHO DA ZONA ── */
function updateSize() {
    const width = parseFloat(document.getElementById('widthSlider').value);
    const depth = parseFloat(document.getElementById('depthSlider').value);
    document.getElementById('widthVal').textContent = width.toFixed(1);
    document.getElementById('depthVal').textContent = depth.toFixed(1);
    fetch('https://sradar/updateSize', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ width: width, depth: depth })
    });
}

/* ── CONFIRMAR / CANCELAR ── */
function confirmPlacement() {
    fetch('https://sradar/confirm', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({})
    });
}

function goBack() {
    fetch('https://sradar/cancel', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({})
    });
}

function deleteRadar(id) {
    if (window.confirm('Excluir radar #' + id + '?')) {
        fetch('https://sradar/deleteRadar', {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify({ id: id })
        }).then(() => {
            document.getElementById('radarUI').classList.remove('active');
        });
    }
}

/* ── TECLADO ── */
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        goBack();
        return;
    }

    if (document.getElementById('creatorView').style.display !== 'none') {
        const k = e.key.toLowerCase();
        if (k === 'w') move('forward');
        if (k === 's') move('back');
        if (k === 'a') move('left');
        if (k === 'd') move('right');
        if (k === 'q') rotate('left');
        if (k === 'e') rotate('right');
    }
});