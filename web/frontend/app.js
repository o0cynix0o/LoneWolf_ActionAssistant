const state = {
  payload: null,
  activeTab: 'overview',
  message: '',
};

const elements = {
  statusLine: document.getElementById('status-line'),
  readerTitle: document.getElementById('reader-title'),
  readerFrame: document.getElementById('reader-frame'),
  summaryGrid: document.getElementById('summary-grid'),
  view: document.getElementById('view'),
  messageBar: document.getElementById('message-bar'),
  tabbar: document.getElementById('tabbar'),
  sectionInput: document.getElementById('section-input'),
  commandInput: document.getElementById('command-input'),
  jumpSectionBtn: document.getElementById('jump-section-btn'),
  runCommandBtn: document.getElementById('run-command-btn'),
};

async function apiState() {
  const response = await fetch('/api/state');
  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(data.message || 'Failed to load state.');
  }
  return data;
}

async function apiAction(payload) {
  const response = await fetch('/api/action', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(data.message || 'Action failed.');
  }
  return data;
}

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function text(value, fallback = '(none)') {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }
  return String(value);
}

function renderSummaryCards(payload) {
  const cards = [];
  if (payload?.session?.HasState) {
    cards.push(['Character', text(payload.character?.Name)]);
    cards.push(['Book', `Book ${payload.reader?.BookNumber} - ${text(payload.reader?.BookTitle, 'Unknown')}`]);
    cards.push(['Section', text(payload.reader?.Section)]);
    cards.push(['END', `${text(payload.character?.EnduranceCurrent, '0')} / ${text(payload.character?.EnduranceMax, '0')}`]);
    cards.push(['Gold', text(payload.inventory?.GoldCrowns, '0')]);
  } else {
    cards.push(['Session', 'No active run']);
    cards.push(['Screen', text(payload?.session?.CurrentScreen, 'welcome')]);
    cards.push(['Saves', String(safeArray(payload?.saves).length)]);
    cards.push(['Engine', text(payload?.app?.Version, '0.8.0')]);
    cards.push(['Mode', 'Welcome']);
  }

  elements.summaryGrid.innerHTML = cards.map(([label, value]) => `
    <article class="summary-card">
      <span>${label}</span>
      <strong>${value}</strong>
    </article>
  `).join('');
}

function renderOverview(payload) {
  const campaign = payload.campaign || null;
  const disciplines = [
    ...safeArray(payload.character?.Disciplines),
    ...safeArray(payload.character?.MagnakaiDisciplines),
  ];

  return `
    <section class="panel">
      <h2>Run Overview</h2>
      <div class="kv-grid">
        <div class="kv"><span>Current Screen</span><strong>${text(payload.session?.CurrentScreen)}</strong></div>
        <div class="kv"><span>Rule Set</span><strong>${text(payload.app?.RuleSet)}</strong></div>
        <div class="kv"><span>Combat Skill</span><strong>${text(payload.character?.CombatSkillBase, '0')}</strong></div>
        <div class="kv"><span>Completed Books</span><strong>${safeArray(payload.character?.CompletedBooks).join(', ') || '(none)'}</strong></div>
      </div>
    </section>
    <section class="panel">
      <h2>Disciplines</h2>
      <div class="inventory-list">
        ${disciplines.length ? disciplines.map(item => `<span class="pill">${item}</span>`).join(' ') : '<p class="muted">(none recorded)</p>'}
      </div>
    </section>
    <section class="panel">
      <h2>Campaign Snapshot</h2>
      ${campaign ? `
        <div class="kv-grid">
          <div class="kv"><span>Difficulty</span><strong>${text(campaign.Difficulty)}</strong></div>
          <div class="kv"><span>Permadeath</span><strong>${campaign.PermadeathEnabled ? 'On' : 'Off'}</strong></div>
          <div class="kv"><span>Sections Visited</span><strong>${text(campaign.SectionsVisited, '0')}</strong></div>
          <div class="kv"><span>Run Style</span><strong>${text(campaign.RunStyle)}</strong></div>
          <div class="kv"><span>Victories</span><strong>${text(campaign.Victories, '0')}</strong></div>
          <div class="kv"><span>Deaths / Rewinds</span><strong>${text(campaign.Deaths, '0')} / ${text(campaign.RewindsUsed, '0')}</strong></div>
        </div>
      ` : '<p class="muted">No campaign summary is available until a run is loaded.</p>'}
    </section>
  `;
}

function renderInventory(payload) {
  const sections = [
    ['Weapons', safeArray(payload.inventory?.Weapons)],
    ['Backpack', safeArray(payload.inventory?.BackpackItems)],
    ['Special', safeArray(payload.inventory?.SpecialItems)],
    ['Pocket', safeArray(payload.inventory?.PocketSpecialItems)],
    ['Herb Pouch', safeArray(payload.inventory?.HerbPouchItems)],
  ];

  return `
    <section class="panel">
      <h2>Inventory</h2>
      <div class="inventory-grid">
        ${sections.map(([title, items]) => `
          <article class="panel">
            <h2>${title}</h2>
            <div class="inventory-list">
              ${items.length ? items.map(item => `<span class="pill">${item}</span>`).join(' ') : '<p class="muted">(empty)</p>'}
            </div>
          </article>
        `).join('')}
      </div>
    </section>
  `;
}

function renderCombat(payload) {
  const combat = payload.combat || {};
  const rows = [
    ['Enemy', text(combat.EnemyName)],
    ['Enemy CS', text(combat.EnemyCombatSkill, '0')],
    ['Enemy END', `${text(combat.EnemyEnduranceCurrent, '0')} / ${text(combat.EnemyEnduranceMax, '0')}`],
    ['Weapon', text(combat.EquippedWeapon)],
    ['Mindblast', combat.UseMindblast ? 'On' : 'Off'],
    ['Evade', combat.CanEvade ? 'Available' : 'No'],
  ];

  const rounds = safeArray(combat.Log).slice(-8);

  return `
    <section class="panel">
      <h2>Combat</h2>
      <div class="kv-grid">
        <div class="kv"><span>Status</span><strong>${combat.Active ? 'Active' : 'Inactive'}</strong></div>
        ${rows.map(([label, value]) => `<div class="kv"><span>${label}</span><strong>${value}</strong></div>`).join('')}
      </div>
    </section>
    <section class="panel">
      <h2>Recent Combat Rounds</h2>
      ${rounds.length ? rounds.map(round => `
        <div class="history-row">
          <strong>Round ${text(round.Round, '?')}</strong>
          <div class="history-meta">Roll ${text(round.Roll, '?')} | Ratio ${text(round.Ratio, '?')} | Enemy Loss ${text(round.EnemyLoss, '0')} | Player Loss ${text(round.PlayerLoss, '0')}</div>
        </div>
      `).join('') : '<p class="muted">No combat rounds are recorded for the current fight.</p>'}
    </section>
  `;
}

function renderSaves(payload) {
  const saves = safeArray(payload.saves);
  return `
    <section class="panel">
      <h2>Saves</h2>
      ${saves.length ? saves.map(save => `
        <article class="save-row">
          <strong>${text(save.Name)}</strong>
          <div class="save-meta">
            ${save.BookNumber ? `Book ${save.BookNumber}` : 'Book ?'} |
            ${text(save.RuleSet, '?')} |
            ${text(save.Difficulty, '?')} |
            ${text(save.CharacterName, '')}
          </div>
          <div class="save-actions">
            <button type="button" data-load-path="${save.FullName}">Load</button>
            <span class="muted">${text(save.LastWriteTime, '')}</span>
          </div>
        </article>
      `).join('') : '<p class="muted">No saves found.</p>'}
    </section>
  `;
}

function renderHistory(payload) {
  const entries = safeArray(payload.history).slice().reverse();
  return `
    <section class="panel">
      <h2>Recent Combat History</h2>
      ${entries.length ? entries.map(entry => `
        <article class="history-row">
          <strong>${text(entry.EnemyName)}</strong>
          <div class="history-meta">
            ${text(entry.Outcome)} | ${text(entry.Weapon)} | ${entry.BookNumber ? `Book ${entry.BookNumber}` : ''} ${entry.Section ? `Section ${entry.Section}` : ''}
          </div>
          <div class="history-meta">
            Rounds ${text(entry.RoundCount, '0')} | Ratio ${text(entry.CombatRatio, '0')} | Player END ${text(entry.PlayerEnd, '0')} | Enemy END ${text(entry.EnemyEnd, '0')}
          </div>
        </article>
      `).join('') : '<p class="muted">No combat history recorded yet.</p>'}
    </section>
  `;
}

function renderNotes(payload) {
  const notes = safeArray(payload.notes);
  return `
    <section class="panel">
      <h2>Notes</h2>
      ${notes.length ? notes.map(note => `<article class="note-row"><strong>${note}</strong></article>`).join('') : '<p class="muted">No notes recorded.</p>'}
    </section>
  `;
}

function renderView() {
  const payload = state.payload;
  if (!payload) {
    elements.view.innerHTML = '<section class="panel"><h2>Loading</h2><p class="muted">Waiting for the local Lone Wolf web session.</p></section>';
    return;
  }

  if (!payload.session?.HasState) {
    elements.view.innerHTML = `
      <section class="panel">
        <h2>No Active Run</h2>
        <p class="muted">Load your last save, load a catalog entry, or keep the reader open on the library while the migration scaffold grows into a full play surface.</p>
      </section>
      ${renderSaves(payload)}
    `;
    return;
  }

  switch (state.activeTab) {
    case 'inventory':
      elements.view.innerHTML = renderInventory(payload);
      break;
    case 'combat':
      elements.view.innerHTML = renderCombat(payload);
      break;
    case 'saves':
      elements.view.innerHTML = renderSaves(payload);
      break;
    case 'history':
      elements.view.innerHTML = renderHistory(payload);
      break;
    case 'notes':
      elements.view.innerHTML = renderNotes(payload);
      break;
    default:
      elements.view.innerHTML = renderOverview(payload);
      break;
  }

  document.querySelectorAll('[data-load-path]').forEach(button => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'loadGame', path: button.dataset.loadPath });
        applyResponse(result);
      } catch (error) {
        setMessage(error.message, true);
      }
    });
  });
}

function syncReader(payload) {
  const url = payload?.reader?.Url || '/web/frontend/library.html';
  elements.readerTitle.textContent = payload?.session?.HasState
    ? `Book ${payload.reader.BookNumber} - ${text(payload.reader.BookTitle)} | Section ${text(payload.reader.Section)}`
    : 'Reader Home';

  const current = elements.readerFrame.getAttribute('src');
  if (current !== url && state.followCurrent !== false) {
    elements.readerFrame.setAttribute('src', url);
  }
}

function setMessage(message, isError = false) {
  state.message = message || '';
  elements.messageBar.textContent = message || 'Ready.';
  elements.messageBar.style.color = isError ? 'var(--danger)' : 'var(--muted)';
}

function applyResponse(response) {
  state.payload = response.payload;
  elements.statusLine.textContent = `Screen: ${text(response.payload?.session?.CurrentScreen, 'welcome')} | Engine ${text(response.payload?.app?.Version, '0.8.0')}`;
  renderSummaryCards(response.payload);
  syncReader(response.payload);
  renderView();
  setMessage(response.message || 'Ready.');
}

async function refreshState() {
  try {
    const response = await apiState();
    applyResponse(response);
  } catch (error) {
    setMessage(error.message, true);
  }
}

function attachEvents() {
  elements.tabbar.querySelectorAll('button').forEach(button => {
    button.addEventListener('click', () => {
      state.activeTab = button.dataset.tab;
      elements.tabbar.querySelectorAll('button').forEach(item => item.classList.toggle('active', item === button));
      renderView();
    });
  });

  document.querySelectorAll('[data-screen]').forEach(button => {
    button.addEventListener('click', async () => {
      try {
        const response = await apiAction({ action: 'showScreen', name: button.dataset.screen });
        applyResponse(response);
      } catch (error) {
        setMessage(error.message, true);
      }
    });
  });

  document.querySelector('[data-action="open-library"]').addEventListener('click', () => {
    state.followCurrent = false;
    elements.readerFrame.setAttribute('src', '/web/frontend/library.html');
    elements.readerTitle.textContent = 'Reader Home';
  });

  document.querySelector('[data-action="follow-current"]').addEventListener('click', () => {
    state.followCurrent = true;
    if (state.payload) {
      syncReader(state.payload);
    }
  });

  document.querySelector('[data-action="reload-state"]').addEventListener('click', refreshState);

  elements.jumpSectionBtn.addEventListener('click', async () => {
    const section = Number(elements.sectionInput.value || 0);
    if (!section) {
      setMessage('Enter a section number first.', true);
      return;
    }
    try {
      const response = await apiAction({ action: 'setSection', section });
      state.followCurrent = true;
      applyResponse(response);
    } catch (error) {
      setMessage(error.message, true);
    }
  });

  elements.runCommandBtn.addEventListener('click', async () => {
    const command = elements.commandInput.value.trim();
    if (!command) {
      setMessage('Enter a safe web command first.', true);
      return;
    }
    try {
      const response = await apiAction({ action: 'safeCommand', command });
      state.followCurrent = command.startsWith('set ');
      applyResponse(response);
    } catch (error) {
      setMessage(error.message, true);
    }
  });
}

attachEvents();
refreshState();
