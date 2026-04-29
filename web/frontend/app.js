const state = {
  payload: null,
  activeTab: 'overview',
  followCurrent: true,
  message: '',
  readerSyncInFlight: false,
};

const FOLDER_TO_BOOK = {
  '01fftd': 1,
  '02fotw': 2,
  '03tcok': 3,
  '04tcod': 4,
  '05sots': 5,
  '06tkot': 6,
  '07cd': 7,
  '08tjoh': 8,
  '09tcof': 9,
  '10tdot': 10,
  '11tpot': 11,
  '12tmod': 12,
  '13tplor': 13,
  '14tcok': 14,
  '15tdc': 15,
  '16tlov': 16,
  '17tdoi': 17,
  '18dotd': 18,
  '19wb': 19,
  '20tcon': 20,
  '21votm': 21,
  '22tbos': 22,
  '23mh': 23,
  '24rw': 24,
  '25totw': 25,
  '26tfobm': 26,
  '27v': 27,
  '28thos': 28,
  '29tsoc': 29,
};

const elements = {
  statusLine: document.getElementById('status-line'),
  readerTitle: document.getElementById('reader-title'),
  readerFrame: document.getElementById('reader-frame'),
  summaryGrid: document.getElementById('summary-grid'),
  flowHost: document.getElementById('flow-host'),
  view: document.getElementById('view'),
  messageBar: document.getElementById('message-bar'),
  tabbar: document.getElementById('tabbar'),
  sectionInput: document.getElementById('section-input'),
  commandInput: document.getElementById('command-input'),
  jumpSectionBtn: document.getElementById('jump-section-btn'),
  runCommandBtn: document.getElementById('run-command-btn'),
  newGameBtn: document.getElementById('new-game-btn'),
  loadLastSaveBtn: document.getElementById('load-last-save-btn'),
  saveGameBtn: document.getElementById('save-game-btn'),
};

async function apiState() {
  const response = await fetch('/api/state');
  const data = await response.json();
  if (!response.ok || !data.ok) {
    const error = new Error(data.message || 'Failed to load state.');
    error.responseData = data;
    throw error;
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
    const error = new Error(data.message || 'Action failed.');
    error.responseData = data;
    throw error;
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

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function extractFlowChoices(contextText) {
  const lines = String(contextText || '').split(/\r?\n/);
  const choices = [];
  for (const line of lines) {
    const match = line.match(/^\s*([A-Za-z0-9]+)\.\s+(.+?)\s*$/);
    if (!match) {
      continue;
    }
    choices.push({
      value: match[1],
      label: match[2],
    });
  }
  return choices;
}

function formatMessage(value, fallback = 'Ready.') {
  if (Array.isArray(value)) {
    for (let index = value.length - 1; index >= 0; index -= 1) {
      const item = value[index];
      if (typeof item === 'string' && item.trim()) {
        return item;
      }
    }
    return fallback;
  }

  return text(value, fallback);
}

function formatTimestamp(value) {
  if (!value) {
    return '(unknown)';
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return text(value, '(unknown)');
  }

  return date.toLocaleString();
}

function getTabForScreen(screenName) {
  switch (String(screenName || '').toLowerCase()) {
    case 'sheet':
    case 'disciplines':
    case 'help':
      return 'overview';
    case 'inventory':
      return 'inventory';
    case 'stats':
      return 'stats';
    case 'campaign':
      return 'campaign';
    case 'achievements':
      return 'achievements';
    case 'combat':
    case 'combatlog':
      return 'combat';
    case 'history':
      return 'history';
    case 'notes':
      return 'notes';
    case 'saves':
      return 'saves';
    default:
      return null;
  }
}

function syncActiveTabButtons() {
  elements.tabbar.querySelectorAll('button').forEach((button) => {
    button.classList.toggle('active', button.dataset.tab === state.activeTab);
  });
}

function renderNamedCountCloud(items, emptyLabel = '(none)') {
  const entries = safeArray(items);
  if (!entries.length) {
    return `<p class="muted">${emptyLabel}</p>`;
  }

  return `
    <div class="chip-cloud">
      ${entries.map((entry) => `
        <span class="pill">
          ${escapeHtml(text(entry.Name, '(unknown)'))}
          <strong>${escapeHtml(text(entry.Count, '0'))}</strong>
        </span>
      `).join('')}
    </div>
  `;
}

function getUniqueCampaignBookEntries(bookEntries) {
  const byBook = new Map();
  safeArray(bookEntries).forEach((entry) => {
    const bookNumber = Number(entry?.Summary?.BookNumber || 0);
    if (!bookNumber) {
      return;
    }
    byBook.set(bookNumber, entry);
  });

  return Array.from(byBook.values()).sort((left, right) => {
    return Number(left?.Summary?.BookNumber || 0) - Number(right?.Summary?.BookNumber || 0);
  });
}

function getReaderPageInfo() {
  try {
    const href = elements.readerFrame.contentWindow?.location?.href
      || elements.readerFrame.getAttribute('src')
      || '';
    const url = new URL(href, window.location.origin);
    if (url.pathname === '/web/frontend/library.html') {
      return { type: 'library', url: url.pathname };
    }

    const match = url.pathname.match(/^\/books\/lw\/([^/]+)\/sect(\d+)\.htm$/i);
    if (!match) {
      return { type: 'other', url: url.pathname };
    }

    const folder = match[1].toLowerCase();
    return {
      type: 'section',
      url: url.pathname,
      folder,
      bookNumber: FOLDER_TO_BOOK[folder] || null,
      section: Number(match[2]),
    };
  } catch (_error) {
    return null;
  }
}

function updateReaderTitleFromPageInfo(info) {
  if (!info) {
    return;
  }

  if (info.type === 'library') {
    if (!state.payload?.session?.HasState) {
      elements.readerTitle.textContent = 'Reader Home';
    }
    return;
  }

  if (info.type !== 'section') {
    return;
  }

  const payload = state.payload;
  const activeBookNumber = Number(payload?.reader?.BookNumber || 0);
  const activeBookTitle = payload?.reader?.BookTitle || '';
  const title = info.bookNumber === activeBookNumber && activeBookTitle
    ? `Book ${info.bookNumber} - ${activeBookTitle} | Section ${info.section}`
    : `Book ${text(info.bookNumber, '?')} | Section ${info.section}`;
  elements.readerTitle.textContent = title;
}

async function handleReaderNavigation() {
  const info = getReaderPageInfo();
  updateReaderTitleFromPageInfo(info);

  if (!info || info.type !== 'section') {
    return;
  }

  const payload = state.payload;
  if (!payload?.session?.HasState) {
    return;
  }
  if (payload?.pendingFlow?.Active || payload?.combat?.Active) {
    return;
  }

  const currentBook = Number(payload.reader?.BookNumber || 0);
  const currentSection = Number(payload.reader?.Section || 0);
  if (!info.bookNumber || info.bookNumber !== currentBook || info.section === currentSection) {
    return;
  }

  if (state.readerSyncInFlight) {
    return;
  }

  state.readerSyncInFlight = true;
  try {
    state.followCurrent = true;
    const response = await apiAction({ action: 'setSection', section: info.section });
    applyResponse(response);
  } catch (error) {
    handleActionError(error);
  } finally {
    state.readerSyncInFlight = false;
  }
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
    cards.push(['Mode', payload?.pendingFlow?.Active ? 'Setup Flow' : 'Welcome']);
  }

  elements.summaryGrid.innerHTML = cards.map(([label, value]) => `
    <article class="summary-card">
      <span>${label}</span>
      <strong>${value}</strong>
    </article>
  `).join('');
}

function renderDisciplineGroup(title, disciplines, tone = '') {
  const list = safeArray(disciplines);
  const toneClass = tone ? ` discipline-group-${tone}` : '';
  return `
    <div class="discipline-group${toneClass}">
      <h3>${escapeHtml(title)}</h3>
      ${list.length ? `
        <div class="discipline-grid">
          ${list.map((item) => `<span class="discipline-chip">${escapeHtml(item)}</span>`).join('')}
        </div>
      ` : '<p class="muted">(none)</p>'}
    </div>
  `;
}

function renderOverview(payload) {
  const campaign = payload.campaign || null;
  const kaiDisciplines = safeArray(payload.character?.Disciplines);
  const magnakaiDisciplines = safeArray(payload.character?.MagnakaiDisciplines);

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
      ${(kaiDisciplines.length || magnakaiDisciplines.length) ? `
        <div class="discipline-groups">
          ${renderDisciplineGroup('Kai', kaiDisciplines, 'kai')}
          ${renderDisciplineGroup('Magnakai', magnakaiDisciplines, 'magnakai')}
        </div>
      ` : '<p class="muted">(none recorded)</p>'}
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

function renderStats(payload) {
  const stats = payload.currentBookStats || null;
  if (!stats) {
    return `
      <section class="panel">
        <h2>Current Book Stats</h2>
        <p class="muted">No live book summary is available yet for this run.</p>
      </section>
    `;
  }

  return `
    <section class="panel">
      <h2>Current Book Summary</h2>
      <div class="kv-grid">
        <div class="kv"><span>Book</span><strong>Book ${text(stats.BookNumber, '?')} - ${text(stats.BookTitle, 'Unknown')}</strong></div>
        <div class="kv"><span>Difficulty</span><strong>${text(stats.Difficulty)}</strong></div>
        <div class="kv"><span>Permadeath</span><strong>${stats.Permadeath ? 'On' : 'Off'}</strong></div>
        <div class="kv"><span>Integrity</span><strong>${text(stats.RunIntegrityState)}</strong></div>
        <div class="kv"><span>Start / Last Section</span><strong>${text(stats.StartSection, '0')} / ${text(stats.LastSection, '0')}</strong></div>
        <div class="kv"><span>Path Sections</span><strong>${text(stats.SuccessfulPathSections, '0')}</strong></div>
        <div class="kv"><span>Sections Seen</span><strong>${text(stats.SectionsVisited, '0')}</strong></div>
        <div class="kv"><span>Unique Sections</span><strong>${text(stats.UniqueSectionsVisited, '0')}</strong></div>
        <div class="kv"><span>END Lost / Gained</span><strong>${text(stats.EnduranceLost, '0')} / ${text(stats.EnduranceGained, '0')}</strong></div>
        <div class="kv"><span>Gold Gained / Spent</span><strong>${text(stats.GoldGained, '0')} / ${text(stats.GoldSpent, '0')}</strong></div>
        <div class="kv"><span>Deaths / Rewinds</span><strong>${text(stats.DeathCount, '0')} / ${text(stats.RewindsUsed, '0')}</strong></div>
        <div class="kv"><span>Run Style</span><strong>${stats.PartialTracking ? 'Partial Tracking' : 'Tracked Run'}</strong></div>
      </div>
    </section>
    <section class="panel-grid">
      <section class="panel">
        <h2>Survival & Recovery</h2>
        <div class="kv-grid">
          <div class="kv"><span>Meals Eaten</span><strong>${text(stats.MealsEaten, '0')}</strong></div>
          <div class="kv"><span>Hunting Meals</span><strong>${text(stats.MealsCoveredByHunting, '0')}</strong></div>
          <div class="kv"><span>Starvation Penalties</span><strong>${text(stats.StarvationPenalties, '0')}</strong></div>
          <div class="kv"><span>Potions Used</span><strong>${text(stats.PotionsUsed, '0')}</strong></div>
          <div class="kv"><span>Strong Potions</span><strong>${text(stats.ConcentratedPotionsUsed, '0')}</strong></div>
          <div class="kv"><span>Potion END</span><strong>${text(stats.PotionEnduranceRestored, '0')}</strong></div>
          <div class="kv"><span>Healing Triggers</span><strong>${text(stats.HealingTriggers, '0')}</strong></div>
          <div class="kv"><span>Healing END</span><strong>${text(stats.HealingEnduranceRestored, '0')}</strong></div>
          <div class="kv"><span>Manual Recoveries</span><strong>${text(stats.ManualRecoveryShortcuts, '0')}</strong></div>
          <div class="kv"><span>Instant Deaths</span><strong>${text(stats.InstantDeaths, '0')}</strong></div>
        </div>
      </section>
      <section class="panel">
        <h2>Combat Benchmarks</h2>
        <div class="kv-grid">
          <div class="kv"><span>Combats</span><strong>${text(stats.CombatCount, '0')}</strong></div>
          <div class="kv"><span>Victories / Defeats</span><strong>${text(stats.Victories, '0')} / ${text(stats.Defeats, '0')}</strong></div>
          <div class="kv"><span>Evades</span><strong>${text(stats.Evades, '0')}</strong></div>
          <div class="kv"><span>Rounds Fought</span><strong>${text(stats.RoundsFought, '0')}</strong></div>
          <div class="kv"><span>Mindblast Combats</span><strong>${text(stats.MindblastCombats, '0')}</strong></div>
          <div class="kv"><span>Mindblast Wins</span><strong>${text(stats.MindblastVictories, '0')}</strong></div>
          <div class="kv"><span>Highest CS Faced</span><strong>${text(stats.HighestEnemyCombatSkillFaced, '0')}</strong></div>
          <div class="kv"><span>Highest END Faced</span><strong>${text(stats.HighestEnemyEnduranceFaced, '0')}</strong></div>
          <div class="kv"><span>Highest CS Defeated</span><strong>${text(stats.HighestEnemyCombatSkillDefeated, '0')}</strong></div>
          <div class="kv"><span>Highest END Defeated</span><strong>${text(stats.HighestEnemyEnduranceDefeated, '0')}</strong></div>
        </div>
        <div class="detail-list">
          <div class="detail-row"><span>Fastest Victory</span><strong>${text(stats.FastestVictoryEnemyName)} ${stats.FastestVictoryRounds ? `(${stats.FastestVictoryRounds} round${Number(stats.FastestVictoryRounds) === 1 ? '' : 's'})` : ''}</strong></div>
          <div class="detail-row"><span>Easiest Victory</span><strong>${text(stats.EasiestVictoryEnemyName)} ${stats.EasiestVictoryRatio ? `(ratio ${stats.EasiestVictoryRatio})` : ''}</strong></div>
          <div class="detail-row"><span>Longest Fight</span><strong>${text(stats.LongestFightEnemyName)} ${stats.LongestFightRounds ? `(${stats.LongestFightRounds} round${Number(stats.LongestFightRounds) === 1 ? '' : 's'})` : ''}</strong></div>
        </div>
      </section>
    </section>
    <section class="panel-grid">
      <section class="panel">
        <h2>Weapon Usage</h2>
        ${renderNamedCountCloud(stats.WeaponUsage, 'No weapon usage has been logged yet.')}
      </section>
      <section class="panel">
        <h2>Weapon Victories</h2>
        ${renderNamedCountCloud(stats.WeaponVictories, 'No weapon victories have been logged yet.')}
      </section>
    </section>
    <section class="panel">
      <h2>Completion Quote</h2>
      <p class="feature-quote">${text(stats.CompletionQuote, 'No current completion quote is available yet.')}</p>
    </section>
  `;
}

function renderCampaign(payload) {
  const campaign = payload.campaign || null;
  if (!campaign) {
    return `
      <section class="panel">
        <h2>Campaign Review</h2>
        <p class="muted">No campaign summary is available until a run is loaded.</p>
      </section>
    `;
  }

  const bookEntries = getUniqueCampaignBookEntries(campaign.BookEntries);
  const recentAchievements = safeArray(campaign.RecentAchievements);

  return `
    <section class="panel">
      <h2>Campaign Overview</h2>
      <div class="kv-grid">
        <div class="kv"><span>Character</span><strong>${text(campaign.CharacterName)}</strong></div>
        <div class="kv"><span>Current Book</span><strong>${text(campaign.CurrentBookLabel)}</strong></div>
        <div class="kv"><span>Rank</span><strong>${text(campaign.CurrentRankLabel)}</strong></div>
        <div class="kv"><span>Run Status</span><strong>${text(campaign.RunStatus)}</strong></div>
        <div class="kv"><span>Difficulty</span><strong>${text(campaign.Difficulty)}</strong></div>
        <div class="kv"><span>Permadeath</span><strong>${campaign.PermadeathEnabled ? 'On' : 'Off'}</strong></div>
        <div class="kv"><span>Integrity</span><strong>${text(campaign.RunIntegrityState)}</strong></div>
        <div class="kv"><span>Run Style</span><strong>${text(campaign.RunStyle)}</strong></div>
        <div class="kv"><span>Achievement Pool</span><strong>${text(campaign.AchievementPoolLabel)}</strong></div>
        <div class="kv"><span>Achievements</span><strong>${text(campaign.AchievementsUnlocked, '0')} / ${text(campaign.AchievementsAvailable, '0')}</strong></div>
        <div class="kv"><span>Profile Totals</span><strong>${text(campaign.ProfileAchievementsUnlocked, '0')} / ${text(campaign.ProfileAchievementsAvailable, '0')}</strong></div>
        <div class="kv"><span>Books Completed</span><strong>${text(campaign.BooksCompletedCount, '0')} / ${text(campaign.BooksTrackedCount, '0')}</strong></div>
      </div>
      <div class="detail-list">
        <div class="detail-row"><span>Completed Books</span><strong>${text(campaign.CompletedBooksLabel, '(none)')}</strong></div>
      </div>
    </section>
    <section class="panel">
      <h2>Campaign Totals</h2>
      <div class="metric-grid">
        <div class="kv"><span>Sections Visited</span><strong>${text(campaign.TotalSectionsVisited, '0')}</strong></div>
        <div class="kv"><span>Unique Sections</span><strong>${text(campaign.TotalUniqueSectionsVisited, '0')}</strong></div>
        <div class="kv"><span>Path Sections</span><strong>${text(campaign.TotalSuccessfulPathSections, '0')}</strong></div>
        <div class="kv"><span>END Lost</span><strong>${text(campaign.TotalEnduranceLost, '0')}</strong></div>
        <div class="kv"><span>END Gained</span><strong>${text(campaign.TotalEnduranceGained, '0')}</strong></div>
        <div class="kv"><span>Meals Eaten</span><strong>${text(campaign.TotalMealsEaten, '0')}</strong></div>
        <div class="kv"><span>Hunting Meals</span><strong>${text(campaign.TotalHuntingMeals, '0')}</strong></div>
        <div class="kv"><span>Potions Used</span><strong>${text(campaign.TotalPotionsUsed, '0')}</strong></div>
        <div class="kv"><span>Gold Gained</span><strong>${text(campaign.TotalGoldGained, '0')}</strong></div>
        <div class="kv"><span>Gold Spent</span><strong>${text(campaign.TotalGoldSpent, '0')}</strong></div>
        <div class="kv"><span>Deaths</span><strong>${text(campaign.TotalDeaths, '0')}</strong></div>
        <div class="kv"><span>Rewinds</span><strong>${text(campaign.TotalRewindsUsed, '0')}</strong></div>
      </div>
    </section>
    <section class="panel-grid">
      <section class="panel">
        <h2>Combat Milestones</h2>
        <div class="kv-grid">
          <div class="kv"><span>Total Combats</span><strong>${text(campaign.TotalCombatCount, '0')}</strong></div>
          <div class="kv"><span>Victories / Defeats</span><strong>${text(campaign.TotalVictories, '0')} / ${text(campaign.TotalDefeats, '0')}</strong></div>
          <div class="kv"><span>Total Rounds</span><strong>${text(campaign.TotalRoundsFought, '0')}</strong></div>
          <div class="kv"><span>Mindblast Wins</span><strong>${text(campaign.TotalMindblastVictories, '0')}</strong></div>
          <div class="kv"><span>Highest CS Faced</span><strong>${text(campaign.HighestEnemyCombatSkillFaced, '0')}</strong></div>
          <div class="kv"><span>Highest END Faced</span><strong>${text(campaign.HighestEnemyEnduranceFaced, '0')}</strong></div>
          <div class="kv"><span>Highest CS Defeated</span><strong>${text(campaign.HighestEnemyCombatSkillDefeated, '0')}</strong></div>
          <div class="kv"><span>Highest END Defeated</span><strong>${text(campaign.HighestEnemyEnduranceDefeated, '0')}</strong></div>
        </div>
        <div class="detail-list">
          <div class="detail-row"><span>Fastest Victory</span><strong>${text(campaign.FastestVictoryEnemyName)} ${campaign.FastestVictoryRounds ? `(${campaign.FastestVictoryRounds} round${Number(campaign.FastestVictoryRounds) === 1 ? '' : 's'}, ${text(campaign.FastestVictoryBookLabel, 'book unknown')})` : ''}</strong></div>
          <div class="detail-row"><span>Easiest Victory</span><strong>${text(campaign.EasiestVictoryEnemyName)} ${campaign.EasiestVictoryRatio ? `(ratio ${campaign.EasiestVictoryRatio}, ${text(campaign.EasiestVictoryBookLabel, 'book unknown')})` : ''}</strong></div>
          <div class="detail-row"><span>Longest Fight</span><strong>${text(campaign.LongestFightEnemyName)} ${campaign.LongestFightRounds ? `(${campaign.LongestFightRounds} round${Number(campaign.LongestFightRounds) === 1 ? '' : 's'}, ${text(campaign.LongestFightBookLabel, 'book unknown')})` : ''}</strong></div>
        </div>
      </section>
      <section class="panel">
        <h2>Weapon Trends</h2>
        <div class="detail-list">
          <div class="detail-row"><span>Favorite Weapon</span><strong>${campaign.FavoriteWeapon ? `${text(campaign.FavoriteWeapon.Name)} (${text(campaign.FavoriteWeapon.Count, '0')})` : '(none)'}</strong></div>
          <div class="detail-row"><span>Deadliest Weapon</span><strong>${campaign.DeadliestWeapon ? `${text(campaign.DeadliestWeapon.Name)} (${text(campaign.DeadliestWeapon.Count, '0')})` : '(none)'}</strong></div>
        </div>
        <h3 class="subheading">Usage</h3>
        ${renderNamedCountCloud(campaign.WeaponUsage, 'No campaign weapon usage has been logged yet.')}
        <h3 class="subheading">Victories</h3>
        ${renderNamedCountCloud(campaign.WeaponVictories, 'No campaign weapon victories have been logged yet.')}
      </section>
    </section>
    <section class="panel">
      <h2>Books Tracked</h2>
      <div class="book-track-grid">
        ${bookEntries.length ? bookEntries.map((entry) => {
          const summary = entry?.Summary || {};
          return `
            <article class="book-track-card">
              <strong>${text(entry?.Status, 'Tracked')} | Book ${text(summary.BookNumber, '?')} - ${text(summary.BookTitle, 'Unknown')}</strong>
              <div class="history-meta">Sections ${text(summary.SectionsVisited, '0')} (${text(summary.UniqueSectionsVisited, '0')} unique) | Combats ${text(summary.CombatCount, '0')} | Victories ${text(summary.Victories, '0')}</div>
              <div class="history-meta">END ${text(summary.EnduranceLost, '0')} lost / ${text(summary.EnduranceGained, '0')} gained | Gold ${text(summary.GoldGained, '0')} / ${text(summary.GoldSpent, '0')} | Deaths ${text(summary.DeathCount, '0')}</div>
            </article>
          `;
        }).join('') : '<p class="muted">No campaign book entries are recorded yet.</p>'}
      </div>
    </section>
    <section class="panel">
      <h2>Recent Achievements</h2>
      ${recentAchievements.length ? recentAchievements.map((entry) => `
        <article class="history-row">
          <strong>${text(entry.Name)}</strong>
          <div class="history-meta">${text(entry.Category)} | Book ${text(entry.BookNumber, '?')} ${entry.Section ? `| Section ${entry.Section}` : ''}</div>
          <div class="history-meta">${text(entry.Description, '')}</div>
          <div class="history-meta">${formatTimestamp(entry.UnlockedOn)}</div>
        </article>
      `).join('') : '<p class="muted">No recent achievement unlocks are available.</p>'}
    </section>
  `;
}

function renderAchievements(payload) {
  const achievements = payload.achievements || null;
  if (!achievements) {
    return `
      <section class="panel">
        <h2>Achievements</h2>
        <p class="muted">No achievement data is available until a run is loaded.</p>
      </section>
    `;
  }

  const currentBookEntries = safeArray(achievements.CurrentBookEntries);
  const recentUnlocks = safeArray(achievements.RecentUnlocks);
  const bookTotals = safeArray(achievements.BookTotals);

  return `
    <section class="panel">
      <h2>Achievement Overview</h2>
      <div class="kv-grid">
        <div class="kv"><span>Current Book</span><strong>Book ${text(achievements.CurrentBookNumber, '?')} - ${text(achievements.CurrentBookTitle, 'Unknown')}</strong></div>
        <div class="kv"><span>Current Book Progress</span><strong>${text(achievements.CurrentBookUnlocked, '0')} / ${text(achievements.CurrentBookAvailable, '0')}</strong></div>
        <div class="kv"><span>Current Book Total</span><strong>${text(achievements.CurrentBookTotal, '0')}</strong></div>
        <div class="kv"><span>Visible Progress</span><strong>${text(achievements.CurrentBookProgress)}</strong></div>
        <div class="kv"><span>Run Unlocked</span><strong>${text(achievements.UnlockedCount, '0')} / ${text(achievements.AvailableCount, '0')}</strong></div>
        <div class="kv"><span>Profile Unlocked</span><strong>${text(achievements.ProfileUnlockedCount, '0')} / ${text(achievements.ProfileAvailableCount, '0')}</strong></div>
      </div>
    </section>
    <section class="panel">
      <h2>Book Progress</h2>
      <div class="book-total-grid">
        ${bookTotals.length ? bookTotals.map((entry) => `
          <div class="book-total-chip ${entry.Current ? 'book-total-chip-current' : ''}">
            <strong>Book ${text(entry.BookNumber, '?')}</strong>
            <span>${text(entry.BookTitle, 'Unknown')}</span>
            <em>${text(entry.UnlockedCount, '0')} / ${text(entry.TotalCount, '0')}</em>
          </div>
        `).join('') : '<p class="muted">No per-book totals are available yet.</p>'}
      </div>
    </section>
    <section class="panel">
      <h2>Current Book Targets</h2>
      <div class="achievement-grid">
        ${currentBookEntries.length ? currentBookEntries.map((entry) => `
          <article class="achievement-card ${entry.Unlocked ? 'achievement-card-unlocked' : ''} ${entry.AvailableInMode ? '' : 'achievement-card-muted'}">
            <div class="achievement-card-header">
              <strong>${text(entry.Name)}</strong>
              <span class="status-pill ${entry.Unlocked ? 'status-pill-success' : (entry.AvailableInMode ? 'status-pill-warning' : 'status-pill-muted')}">
                ${entry.Unlocked ? 'Unlocked' : (entry.AvailableInMode ? 'Locked' : 'Unavailable')}
              </span>
            </div>
            <div class="history-meta">${text(entry.Category)}</div>
            <p>${text(entry.Description, '')}</p>
            <div class="detail-list compact-detail-list">
              <div class="detail-row"><span>Progress</span><strong>${text(entry.Progress, entry.Unlocked ? 'Complete' : 'Not started')}</strong></div>
              ${entry.AvailableInMode ? '' : `<div class="detail-row"><span>Mode Note</span><strong>${text(entry.AvailabilityReason, 'Unavailable in this run mode')}</strong></div>`}
            </div>
          </article>
        `).join('') : '<p class="muted">No current-book achievements are available.</p>'}
      </div>
    </section>
    <section class="panel">
      <h2>Recent Unlocks</h2>
      ${recentUnlocks.length ? recentUnlocks.map((entry) => `
        <article class="history-row">
          <strong>${text(entry.Name)}</strong>
          <div class="history-meta">${text(entry.Category)} | Book ${text(entry.BookNumber, '?')} ${entry.Section ? `| Section ${entry.Section}` : ''}</div>
          <div class="history-meta">${text(entry.Description, '')}</div>
          <div class="history-meta">${formatTimestamp(entry.UnlockedOn)}</div>
        </article>
      `).join('') : '<p class="muted">No recent unlocks have been recorded yet.</p>'}
    </section>
  `;
}

function renderInventorySection(section) {
  if (!section) {
    return '';
  }

  const slots = safeArray(section.Slots);
  const items = safeArray(section.Items);
  const recoveryItems = safeArray(section.RecoveryItems);
  const hasCapacity = section.Capacity !== null && section.Capacity !== undefined;

  return `
    <article class="panel">
      <h2>${text(section.Label, 'Inventory')}</h2>
      <div class="kv-grid">
        <div class="kv"><span>Used</span><strong>${text(section.Used, '0')}${hasCapacity ? ` / ${text(section.Capacity, '0')}` : ''}</strong></div>
        <div class="kv"><span>Items</span><strong>${text(section.Count, '0')}</strong></div>
        <div class="kv"><span>Container</span><strong>${section.HasContainer === false ? 'Unavailable' : 'Ready'}</strong></div>
        <div class="kv"><span>Recovery Stash</span><strong>${text(section.RecoveryCount, '0')}</strong></div>
      </div>
      ${slots.length ? `
        <div class="slot-list">
          ${slots.map((slot) => `
            <div class="slot-row ${slot.Unavailable ? 'slot-row-muted' : ''}">
              <strong>Slot ${slot.Number}</strong>
              <span>${text(slot.DisplayText, '(empty)')}</span>
            </div>
          `).join('')}
        </div>
      ` : `
        <div class="inventory-list">
          ${items.length ? items.map((item, index) => `<span class="pill">${index + 1}. ${item}</span>`).join(' ') : '<p class="muted">(empty)</p>'}
        </div>
      `}
      ${recoveryItems.length ? `
        <div class="stash-block">
          <p class="muted">Recovery stash</p>
          <div class="inventory-list">
            ${recoveryItems.map((item) => `<span class="pill subtle-pill">${item}</span>`).join(' ')}
          </div>
        </div>
      ` : ''}
    </article>
  `;
}

function renderInventory(payload) {
  const inventory = payload.inventory || {};
  const sections = [
    inventory.Sections?.weapon,
    inventory.Sections?.backpack,
    inventory.Sections?.special,
    inventory.Sections?.pocket,
    inventory.Sections?.herbpouch,
  ].filter(Boolean);

  return `
    <section class="panel">
      <h2>Resources</h2>
      <div class="kv-grid">
        <div class="kv"><span>Gold</span><strong>${text(inventory.GoldCrowns, '0')}</strong></div>
        <div class="kv"><span>END</span><strong>${text(payload.character?.EnduranceCurrent, '0')} / ${text(payload.character?.EnduranceMax, '0')}</strong></div>
        <div class="kv"><span>Quiver</span><strong>${text(inventory.QuiverArrows, '0')} arrow${Number(inventory.QuiverArrows || 0) === 1 ? '' : 's'}</strong></div>
        <div class="kv"><span>Backpack</span><strong>${inventory.HasBackpack ? 'Carried' : 'Missing'}</strong></div>
        <div class="kv"><span>Herb Pouch</span><strong>${inventory.HasHerbPouch ? 'Carried' : 'Missing'}</strong></div>
        <div class="kv"><span>Save Path</span><strong>${text(payload.session?.SavePath, '(not set)')}</strong></div>
      </div>
    </section>
    <section class="panel">
      <h2>Quick Actions</h2>
      <div class="inventory-actions-grid">
        <form id="gold-form" class="flow-form inline-form">
          <label class="flow-field">
            <span>Gold change</span>
            <input id="gold-delta-input" type="number" value="1" step="1" placeholder="+/- Gold">
          </label>
          <div class="flow-actions">
            <button type="submit">Apply Gold</button>
          </div>
        </form>
        <form id="endurance-form" class="flow-form inline-form">
          <label class="flow-field">
            <span>END change</span>
            <input id="endurance-delta-input" type="number" value="-1" step="1" placeholder="+/- END">
          </label>
          <div class="flow-actions">
            <button type="submit">Apply END</button>
          </div>
        </form>
        <div class="panel action-panel">
          <h2>Meals & Potions</h2>
          <p class="muted">These buttons respect the same prompts and restrictions as the terminal app.</p>
          <div class="flow-actions">
            <button type="button" id="use-meal-btn">Use Meal</button>
            <button type="button" id="use-potion-btn">Use Healing Potion</button>
          </div>
        </div>
      </div>
    </section>
    <section class="panel">
      <h2>Manage Inventory</h2>
      <div class="inventory-actions-grid">
        <form id="inventory-add-form" class="flow-form inline-form">
          <div class="flow-grid">
            <label class="flow-field">
              <span>Add type</span>
              <select id="inventory-add-type">
                <option value="weapon">Weapon</option>
                <option value="backpack">Backpack</option>
                <option value="herbpouch">Herb Pouch</option>
                <option value="special">Special</option>
              </select>
            </label>
            <label class="flow-field">
              <span>Quantity</span>
              <input id="inventory-add-quantity" type="number" min="1" value="1">
            </label>
          </div>
          <label class="flow-field">
            <span>Item name</span>
            <input id="inventory-add-name" type="text" placeholder="Meal, Bow, Fireseed, Rope">
          </label>
          <div class="flow-actions">
            <button type="submit">Add Item</button>
          </div>
        </form>
        <form id="inventory-drop-form" class="flow-form inline-form">
          <div class="flow-grid">
            <label class="flow-field">
              <span>Drop type</span>
              <select id="inventory-drop-type">
                <option value="weapon">Weapon</option>
                <option value="backpack">Backpack</option>
                <option value="pocket">Pocket</option>
                <option value="herbpouch">Herb Pouch</option>
                <option value="special">Special</option>
              </select>
            </label>
            <label class="flow-field">
              <span>Slot or all</span>
              <input id="inventory-drop-slot" type="text" placeholder="3 or all">
            </label>
          </div>
          <div class="flow-actions">
            <button type="submit">Drop Item</button>
          </div>
        </form>
        <form id="inventory-recover-form" class="flow-form inline-form">
          <label class="flow-field">
            <span>Recover section</span>
            <select id="inventory-recover-selection">
              <option value="weapon">Weapons</option>
              <option value="backpack">Backpack</option>
              <option value="herbpouch">Herb Pouch</option>
              <option value="special">Special</option>
            </select>
          </label>
          <div class="flow-actions">
            <button type="submit">Recover Section</button>
            <button type="button" class="button-secondary" id="inventory-recover-all-btn">Recover All</button>
          </div>
        </form>
      </div>
    </section>
    <section class="panel">
      <h2>Inventory</h2>
      <div class="inventory-grid">
        ${sections.map((section) => renderInventorySection(section)).join('')}
      </div>
    </section>
  `;
}

function renderCombat(payload) {
  const combat = payload.combat || {};
  const active = Boolean(combat.Active);
  const rounds = safeArray(combat.Log).slice(-8);
  const rows = [
    ['Enemy', text(combat.EnemyName)],
    ['Enemy CS', text(combat.EnemyCombatSkill, '0')],
    ['Enemy END', `${text(combat.EnemyEnduranceCurrent, '0')} / ${text(combat.EnemyEnduranceMax, '0')}`],
    ['Weapon', text(combat.EquippedWeapon)],
    ['Mindblast', combat.UseMindblast ? 'On' : 'Off'],
    ['Evade', combat.CanEvade ? 'Available' : 'No'],
    ['Rounds Logged', String(safeArray(combat.Log).length)],
    ['END Loss Multiplier', text(combat.PlayerEnduranceLossMultiplier, '1')],
  ];

  return `
    <section class="panel">
      <h2>${active ? 'Combat Controls' : 'Start Tracked Combat'}</h2>
      ${active ? `
        <div class="flow-actions combat-actions">
          <button type="button" data-combat-action="combatRound">Resolve Round</button>
          <button type="button" data-combat-action="combatAuto">Auto Resolve</button>
          <button type="button" data-combat-action="combatEvade" ${combat.CanEvade ? '' : 'disabled'}>Evade</button>
          <button type="button" class="button-secondary" data-combat-action="combatStop">Stop Tracking</button>
        </div>
      ` : `
        <p class="muted">Use the tracked combat form when the book calls for a fight and you want the browser UI to drive setup instead of the terminal prompt flow.</p>
        <form id="combat-start-form" class="flow-form">
          <div class="flow-grid">
            <label class="flow-field">
              <span>Enemy name</span>
              <input id="combat-enemy-name" type="text" placeholder="Enemy name">
            </label>
            <label class="flow-field">
              <span>Enemy Combat Skill</span>
              <input id="combat-enemy-cs" type="number" min="0" value="16">
            </label>
            <label class="flow-field">
              <span>Enemy Endurance</span>
              <input id="combat-enemy-end" type="number" min="1" value="20">
            </label>
          </div>
          <div class="flow-actions">
            <button type="submit">Start Combat</button>
          </div>
        </form>
      `}
    </section>
    <section class="panel">
      <h2>Combat</h2>
      <div class="kv-grid">
        <div class="kv"><span>Status</span><strong>${active ? 'Active' : 'Inactive'}</strong></div>
        ${rows.map(([label, value]) => `<div class="kv"><span>${label}</span><strong>${value}</strong></div>`).join('')}
      </div>
    </section>
    <section class="panel">
      <h2>Recent Combat Rounds</h2>
      ${rounds.length ? rounds.map((round) => `
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
  const currentSavePath = text(payload.session?.SavePath, '');
  const hasState = Boolean(payload.session?.HasState);
  return `
    <section class="panel">
      <h2>Save Controls</h2>
      ${hasState ? `
        <div class="kv-grid">
          <div class="kv"><span>Current Save Path</span><strong>${currentSavePath || '(not set yet)'}</strong></div>
          <div class="kv"><span>Active Character</span><strong>${text(payload.character?.Name)}</strong></div>
        </div>
        <form id="save-as-form" class="flow-form">
          <label class="flow-field">
            <span>Save path</span>
            <input id="save-as-path" type="text" value="${payload.session?.SavePath || ''}" placeholder="C:\\Scripts\\Lone Wolf\\saves\\my-run.json">
          </label>
          <div class="flow-actions">
            <button type="submit">Save To Path</button>
            <button type="button" class="button-secondary" id="save-prompt-btn">Choose Path</button>
          </div>
        </form>
      ` : '<p class="muted">Load a run or start a new one before saving.</p>'}
    </section>
    <section class="panel">
      <h2>Saves</h2>
      ${saves.length ? saves.map((save) => `
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
      ${entries.length ? entries.map((entry) => `
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
      <form id="note-form" class="flow-form">
        <label class="flow-field">
          <span>Add a note</span>
          <input id="note-input" type="text" maxlength="240" placeholder="Track a clue, item, or route reminder">
        </label>
        <div class="flow-actions">
          <button type="submit">Add Note</button>
        </div>
      </form>
    </section>
    <section class="panel">
      <h2>Recorded Notes</h2>
      ${notes.length ? notes.map((note, index) => `
        <article class="note-row">
          <strong>Note ${index + 1}</strong>
          <div class="history-meta">${text(note, '')}</div>
          <div class="save-actions">
            <button type="button" class="button-secondary" data-remove-note="${index + 1}">Remove</button>
          </div>
        </article>
      `).join('') : '<p class="muted">No notes recorded.</p>'}
    </section>
  `;
}

function renderBookComplete(payload) {
  const screenData = payload?.session?.ScreenData || {};
  const summary = screenData.Summary || {};
  const snapshot = screenData.Snapshot || {};
  const bookNumber = Number(summary.BookNumber || payload?.reader?.BookNumber || 0);
  const nextBookLabel = text(screenData.ContinueToBookLabel, '');
  const completedBookLabel = bookNumber
    ? `Book ${bookNumber} - ${text(payload?.reader?.BookTitle, 'Unknown')}`
    : text(payload?.reader?.BookTitle, 'Completed Book');
  const finalEndCurrent = text(snapshot.EnduranceCurrent, text(payload?.character?.EnduranceCurrent, '0'));
  const finalEndMax = text(snapshot.EnduranceMax, text(payload?.character?.EnduranceMax, '0'));
  const finalGold = text(snapshot.GoldCrowns, text(payload?.inventory?.GoldCrowns, '0'));

  return `
    <section class="panel">
      <h2>Adventure Complete</h2>
      <div class="kv-grid">
        <div class="kv"><span>Character</span><strong>${text(screenData.CharacterName, text(payload?.character?.Name))}</strong></div>
        <div class="kv"><span>Difficulty</span><strong>${text(snapshot.Difficulty, '(unknown)')}</strong></div>
        <div class="kv"><span>Rule Set</span><strong>${text(snapshot.RuleSet, text(payload?.app?.RuleSet))}</strong></div>
        <div class="kv"><span>Completed Book</span><strong>${completedBookLabel}</strong></div>
        <div class="kv"><span>Final END</span><strong>${finalEndCurrent} / ${finalEndMax}</strong></div>
        <div class="kv"><span>Final Gold</span><strong>${finalGold}</strong></div>
      </div>
      <div class="flow-actions completion-actions">
        ${nextBookLabel ? `<button type="button" id="continue-book-btn">Continue to ${nextBookLabel}</button>` : ''}
      </div>
      <p class="muted completion-note">
        ${nextBookLabel ? `Continue when you're ready to move into ${nextBookLabel} setup.` : 'This campaign has reached its current endpoint.'}
      </p>
    </section>
    <section class="panel">
      <h2>This Playthrough</h2>
      <div class="kv-grid">
        <div class="kv"><span>Sections Seen</span><strong>${text(summary.SectionsVisited, '0')}</strong></div>
        <div class="kv"><span>Unique Sections</span><strong>${text(summary.UniqueSectionsVisited, text(summary.SectionsVisited, '0'))}</strong></div>
        <div class="kv"><span>Combats Fought</span><strong>${text(summary.CombatCount, '0')}</strong></div>
        <div class="kv"><span>Victories</span><strong>${text(summary.Victories, '0')}</strong></div>
        <div class="kv"><span>Deaths</span><strong>${text(summary.DeathCount, '0')}</strong></div>
        <div class="kv"><span>Rewinds Used</span><strong>${text(summary.RewindsUsed, '0')}</strong></div>
        <div class="kv"><span>Gold Gained</span><strong>${text(summary.GoldGained, '0')}</strong></div>
        <div class="kv"><span>Gold Spent</span><strong>${text(summary.GoldSpent, '0')}</strong></div>
      </div>
    </section>
  `;
}

function renderFlowSummary(summary) {
  if (!summary) {
    return '';
  }

  const entries = [];
  if (summary.Difficulty) {
    entries.push(['Difficulty', summary.Difficulty]);
  }
  entries.push(['Permadeath', summary.Permadeath ? 'On' : 'Off']);
  if (summary.Name) {
    entries.push(['Name', summary.Name]);
  }
  if (summary.BookNumber) {
    entries.push(['Book', `Book ${summary.BookNumber}`]);
  }
  if (summary.StartSection) {
    entries.push(['Start', `Section ${summary.StartSection}`]);
  }
  if (summary.Section) {
    entries.push(['Section', `Section ${summary.Section}`]);
  }

  return `
    <div class="flow-summary">
      ${entries.map(([label, value]) => `<span class="pill subtle-pill">${label}: ${value}</span>`).join('')}
    </div>
  `;
}

function renderFlowConfirm(flow) {
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-copy">
        <p>${text(flow.Prompt, '')}</p>
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Continue')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowRunConfig(flow) {
  const options = safeArray(flow.Options);
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-options">
        ${options.map((option) => `
          <label class="flow-option">
            <input type="radio" name="difficulty" value="${option.Value}" ${option.Value === flow.SelectedDifficulty ? 'checked' : ''}>
            <span>
              <strong>${option.Label}</strong>
              <small>${text(option.Description, '')}</small>
            </span>
          </label>
        `).join('')}
      </div>
      <label class="flow-checkbox">
        <input id="flow-permadeath" type="checkbox" ${flow.SelectedPermadeath ? 'checked' : ''}>
        <span>Enable permadeath for this run</span>
      </label>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Next')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowIdentity(flow) {
  const values = flow.Values || {};
  const bookOptions = safeArray(flow.BookOptions);
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-grid">
        <label class="flow-field">
          <span>Character name</span>
          <input id="flow-name" type="text" value="${text(values.Name, 'Lone Wolf')}" maxlength="60">
        </label>
        <label class="flow-field">
          <span>Starting book</span>
          <select id="flow-book-number">
            ${bookOptions.map((option) => `<option value="${option.Value}" ${Number(option.Value) === Number(values.BookNumber) ? 'selected' : ''}>${option.Label}</option>`).join('')}
          </select>
        </label>
        <label class="flow-field">
          <span>Starting section</span>
          <input id="flow-start-section" type="number" min="1" value="${text(values.StartSection, '1')}">
        </label>
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Next')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowSelectMany(flow) {
  const options = safeArray(flow.Options);
  const selected = new Set(safeArray(flow.Selected).map((value) => Number(value)));
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-copy">
        <p>Choose exactly ${text(flow.RequiredCount, '0')} ${text(flow.SelectionKind, 'entries')}.</p>
      </div>
      <div class="flow-options">
        ${options.map((option) => `
          <label class="flow-option">
            <input type="checkbox" name="flow-select" value="${option.Value}" ${selected.has(Number(option.Value)) ? 'checked' : ''}>
            <span>
              <strong>${option.Label}</strong>
              <small>${text(option.Description, '')}</small>
            </span>
          </label>
        `).join('')}
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Next')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowPrompt(flow) {
  const prompt = flow.Prompt || null;
  if (!prompt) {
    return `
      <form id="flow-form" class="flow-form">
        <div class="flow-copy">
          <p>${text(flow.Description, 'Continue into the startup package.')}</p>
        </div>
        <div class="flow-actions">
          <button type="submit">${text(flow.SubmitLabel, 'Continue')}</button>
          <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
        </div>
      </form>
    `;
  }

  let control = '';
  if (prompt.PromptType === 'yesno') {
    const defaultYes = prompt.Default !== false;
    control = `
      <div class="flow-options compact-options">
        <label class="flow-option">
          <input type="radio" name="flow-prompt-value" value="yes" ${defaultYes ? 'checked' : ''}>
          <span><strong>Yes</strong></span>
        </label>
        <label class="flow-option">
          <input type="radio" name="flow-prompt-value" value="no" ${defaultYes ? '' : 'checked'}>
          <span><strong>No</strong></span>
        </label>
      </div>
    `;
  } else if (prompt.PromptType === 'int') {
    const min = prompt.Min ?? '';
    const max = prompt.Max ?? '';
    const value = prompt.Default ?? '';
    control = `<input id="flow-prompt-value" type="number" min="${min}" max="${max}" value="${value}">`;
  } else {
    const value = prompt.Default ?? '';
    control = `<input id="flow-prompt-value" type="text" value="${value}">`;
  }

  const hint = [];
  const quickChoices = extractFlowChoices(flow.ContextText);
  if (prompt.PromptType) {
    hint.push(`Input type: ${prompt.PromptType}`);
  }
  if (prompt.Min !== null && prompt.Min !== undefined) {
    hint.push(`Min ${prompt.Min}`);
  }
  if (prompt.Max !== null && prompt.Max !== undefined) {
    hint.push(`Max ${prompt.Max}`);
  }

  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-copy">
        <p>${text(prompt.Prompt, flow.Description)}</p>
        ${hint.length ? `<p class="muted">${hint.join(' | ')}</p>` : ''}
        ${flow.ContextText ? `<pre class="flow-context">${escapeHtml(flow.ContextText)}</pre>` : ''}
        ${quickChoices.length ? `
          <div class="flow-choice-grid">
            ${quickChoices.map((choice) => `
              <button type="button" class="button-secondary flow-choice-button" data-flow-prompt-choice="${escapeHtml(choice.value)}">
                ${escapeHtml(`${choice.value}. ${choice.label}`)}
              </button>
            `).join('')}
          </div>
        ` : ''}
      </div>
      <div class="flow-field">
        ${control}
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Continue')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderPendingFlow(payload) {
  const flow = payload?.pendingFlow || null;
  if (!flow?.Active) {
    elements.flowHost.innerHTML = '';
    elements.flowHost.classList.add('hidden');
    return;
  }

  let body = '';
  switch (flow.Mode) {
    case 'confirm':
      body = renderFlowConfirm(flow);
      break;
    case 'runConfig':
      body = renderFlowRunConfig(flow);
      break;
    case 'identity':
      body = renderFlowIdentity(flow);
      break;
    case 'selectMany':
      body = renderFlowSelectMany(flow);
      break;
    case 'prompt':
      body = renderFlowPrompt(flow);
      break;
    default:
      body = `
        <form id="flow-form" class="flow-form">
          <div class="flow-copy">
            <p>This flow step is not rendered yet.</p>
          </div>
          <div class="flow-actions">
            <button type="button" class="button-secondary" data-flow-cancel>Cancel</button>
          </div>
        </form>
      `;
      break;
  }

  elements.flowHost.innerHTML = `
    <section class="panel flow-panel">
      <div class="flow-header">
        <div>
          <p class="eyebrow">Structured Flow</p>
          <h2>${text(flow.Title, 'Setup')}</h2>
        </div>
        <span class="flow-step">${text(flow.Step, '')}</span>
      </div>
      <p class="flow-description">${text(flow.Description, '')}</p>
      ${renderFlowSummary(flow.Summary)}
      ${body}
    </section>
  `;
  elements.flowHost.classList.remove('hidden');
  bindFlowEvents(flow);
}

function collectFlowPayload(flow) {
  switch (flow.Mode) {
    case 'confirm':
      return { confirm: true };
    case 'runConfig': {
      const difficulty = document.querySelector('input[name="difficulty"]:checked')?.value || 'Normal';
      const allowPermadeath = difficulty !== 'Story';
      return {
        difficulty,
        permadeath: allowPermadeath && Boolean(document.getElementById('flow-permadeath')?.checked),
      };
    }
    case 'identity':
      return {
        name: document.getElementById('flow-name')?.value || 'Lone Wolf',
        bookNumber: Number(document.getElementById('flow-book-number')?.value || 1),
        startSection: Number(document.getElementById('flow-start-section')?.value || 1),
      };
    case 'selectMany':
      return {
        selected: Array.from(document.querySelectorAll('input[name="flow-select"]:checked')).map((input) => Number(input.value)),
      };
    case 'prompt': {
      const prompt = flow.Prompt || null;
      if (!prompt) {
        return {};
      }

      if (prompt.PromptType === 'yesno') {
        const selected = document.querySelector('input[name="flow-prompt-value"]:checked')?.value;
        return { response: selected === 'yes' };
      }

      if (prompt.PromptType === 'int') {
        const raw = document.getElementById('flow-prompt-value')?.value ?? '';
        return { response: raw === '' ? null : Number(raw) };
      }

      return { response: document.getElementById('flow-prompt-value')?.value ?? '' };
    }
    default:
      return {};
  }
}

function bindFlowEvents(flow) {
  const submitPromptChoice = async (choiceValue) => {
    const prompt = flow?.Prompt || null;
    let response = choiceValue;
    if (prompt?.PromptType === 'yesno') {
      response = ['y', 'yes', 'true', '1'].includes(String(choiceValue).trim().toLowerCase());
    } else if (prompt?.PromptType === 'int') {
      response = Number(choiceValue);
    }

    const result = await apiAction({ action: 'submitFlow', data: { response } });
    applyResponse(result);
  };

  const form = document.getElementById('flow-form');
  if (form) {
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      try {
        const response = await apiAction({ action: 'submitFlow', data: collectFlowPayload(flow) });
        applyResponse(response);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-flow-cancel]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const response = await apiAction({ action: 'cancelFlow' });
        applyResponse(response);
      } catch (error) {
        handleActionError(error);
      }
    });
  });

  document.querySelectorAll('[data-flow-prompt-choice]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        await submitPromptChoice(button.getAttribute('data-flow-prompt-choice') || '');
      } catch (error) {
        handleActionError(error);
      }
    });
  });
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
        <p class="muted">Load your last save, start a new run, or keep the reader open on the library while the web migration keeps growing into a full play surface.</p>
      </section>
      ${renderSaves(payload)}
    `;
  } else if (payload.session?.CurrentScreen === 'bookcomplete') {
    elements.view.innerHTML = renderBookComplete(payload);
  } else {
    switch (state.activeTab) {
      case 'inventory':
        elements.view.innerHTML = renderInventory(payload);
        break;
      case 'stats':
        elements.view.innerHTML = renderStats(payload);
        break;
      case 'campaign':
        elements.view.innerHTML = renderCampaign(payload);
        break;
      case 'achievements':
        elements.view.innerHTML = renderAchievements(payload);
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
  }

  bindDynamicViewEvents(payload);
}

function bindDynamicViewEvents(payload) {
  const continueBookButton = document.getElementById('continue-book-btn');
  if (continueBookButton) {
    continueBookButton.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'continueBook' });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-load-path]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'loadGame', path: button.dataset.loadPath });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  });

  const noteForm = document.getElementById('note-form');
  if (noteForm) {
    noteForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const textValue = document.getElementById('note-input')?.value?.trim() || '';
      if (!textValue) {
        setMessage('Enter note text first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'addNote', text: textValue });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-remove-note]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'removeNote', index: Number(button.dataset.removeNote) });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  });

  const goldForm = document.getElementById('gold-form');
  if (goldForm) {
    goldForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const rawValue = document.getElementById('gold-delta-input')?.value ?? '';
      if (rawValue === '') {
        setMessage('Enter a gold change first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'adjustGold', delta: Number(rawValue) });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const enduranceForm = document.getElementById('endurance-form');
  if (enduranceForm) {
    enduranceForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const rawValue = document.getElementById('endurance-delta-input')?.value ?? '';
      if (rawValue === '') {
        setMessage('Enter an END change first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'adjustEndurance', delta: Number(rawValue) });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const useMealButton = document.getElementById('use-meal-btn');
  if (useMealButton) {
    useMealButton.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'useMeal' });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const usePotionButton = document.getElementById('use-potion-btn');
  if (usePotionButton) {
    usePotionButton.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'usePotion' });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const inventoryAddForm = document.getElementById('inventory-add-form');
  if (inventoryAddForm) {
    inventoryAddForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const type = document.getElementById('inventory-add-type')?.value || 'backpack';
      const name = document.getElementById('inventory-add-name')?.value?.trim() || '';
      const quantity = Number(document.getElementById('inventory-add-quantity')?.value || 1);
      if (!name) {
        setMessage('Enter an item name first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'inventoryAdd', type, name, quantity });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const inventoryDropForm = document.getElementById('inventory-drop-form');
  if (inventoryDropForm) {
    inventoryDropForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const type = document.getElementById('inventory-drop-type')?.value || 'backpack';
      const rawSelection = document.getElementById('inventory-drop-slot')?.value?.trim() || '';
      if (!rawSelection) {
        setMessage('Enter a slot number or all.', true);
        return;
      }
      try {
        const payload = rawSelection.toLowerCase() === 'all'
          ? { action: 'inventoryDrop', type, all: true }
          : { action: 'inventoryDrop', type, slot: Number(rawSelection) };
        const result = await apiAction(payload);
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const inventoryRecoverForm = document.getElementById('inventory-recover-form');
  if (inventoryRecoverForm) {
    inventoryRecoverForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const selection = document.getElementById('inventory-recover-selection')?.value || 'weapon';
      try {
        const result = await apiAction({ action: 'inventoryRecover', selection });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const inventoryRecoverAllButton = document.getElementById('inventory-recover-all-btn');
  if (inventoryRecoverAllButton) {
    inventoryRecoverAllButton.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'inventoryRecover', selection: 'all' });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const saveAsForm = document.getElementById('save-as-form');
  if (saveAsForm) {
    saveAsForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const path = document.getElementById('save-as-path')?.value?.trim() || '';
      if (!path) {
        setMessage('Enter a save path first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'saveGame', path });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const savePromptButton = document.getElementById('save-prompt-btn');
  if (savePromptButton) {
    savePromptButton.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'saveGame', promptForPath: true });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const combatStartForm = document.getElementById('combat-start-form');
  if (combatStartForm) {
    combatStartForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const enemyName = document.getElementById('combat-enemy-name')?.value?.trim() || '';
      const enemyCombatSkill = Number(document.getElementById('combat-enemy-cs')?.value || 0);
      const enemyEndurance = Number(document.getElementById('combat-enemy-end')?.value || 0);
      if (!enemyName) {
        setMessage('Enter an enemy name first.', true);
        return;
      }
      try {
        const result = await apiAction({
          action: 'startCombat',
          enemyName,
          enemyCombatSkill,
          enemyEndurance,
        });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-combat-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: button.dataset.combatAction });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
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
  const previousScreen = String(state.payload?.session?.CurrentScreen || '').toLowerCase();
  state.payload = response.payload;
  const currentScreen = String(response.payload?.session?.CurrentScreen || '').toLowerCase();
  const mappedTab = getTabForScreen(currentScreen);
  if (mappedTab && ['stats', 'campaign', 'achievements'].includes(currentScreen) && currentScreen !== previousScreen) {
    state.activeTab = mappedTab;
  }
  elements.statusLine.textContent = `Screen: ${text(response.payload?.session?.CurrentScreen, 'welcome')} | Engine ${text(response.payload?.app?.Version, '0.8.0')}`;
  elements.saveGameBtn.disabled = !response.payload?.session?.HasState;
  syncActiveTabButtons();
  renderSummaryCards(response.payload);
  renderPendingFlow(response.payload);
  syncReader(response.payload);
  renderView();
  setMessage(formatMessage(response.message, 'Ready.'));
}

function handleActionError(error) {
  if (error?.responseData?.payload) {
    applyResponse(error.responseData);
  }
  setMessage(error.message || 'Action failed.', true);
}

async function refreshState() {
  try {
    const response = await apiState();
    applyResponse(response);
  } catch (error) {
    handleActionError(error);
  }
}

function attachEvents() {
  elements.tabbar.querySelectorAll('button').forEach((button) => {
    button.addEventListener('click', () => {
      state.activeTab = button.dataset.tab;
      syncActiveTabButtons();
      renderView();
    });
  });

  document.querySelectorAll('[data-screen]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const response = await apiAction({ action: 'showScreen', name: button.dataset.screen });
        applyResponse(response);
      } catch (error) {
        handleActionError(error);
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

  elements.readerFrame.addEventListener('load', () => {
    void handleReaderNavigation();
  });

  document.querySelector('[data-action="reload-state"]').addEventListener('click', refreshState);

  elements.newGameBtn.addEventListener('click', async () => {
    try {
      const response = await apiAction({ action: 'startNewGameWizard' });
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

  elements.loadLastSaveBtn.addEventListener('click', async () => {
    try {
      const response = await apiAction({ action: 'loadLastSave' });
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

  elements.saveGameBtn.addEventListener('click', async () => {
    try {
      const response = await apiAction({ action: 'saveGame' });
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

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
      handleActionError(error);
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
      handleActionError(error);
    }
  });
}

attachEvents();
refreshState();
