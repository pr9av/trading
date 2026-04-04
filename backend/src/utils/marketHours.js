/**
 * Market Hours Engine — Blauplug Trading Platform
 * 
 * IST-aware utility for determining NSE market state.
 * NSE trading hours: Monday–Friday, 09:15 – 15:30 IST (UTC+5:30)
 * 
 * Used by: zerodhaTicker, ticks routes, market routes, WebSocket server
 */

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000; // UTC+5:30

/**
 * Get the current time in IST as a Date object.
 */
function nowIST() {
    const now = new Date();
    return new Date(now.getTime() + (now.getTimezoneOffset() * 60 * 1000) + IST_OFFSET_MS);
}

/**
 * Check if the NSE market is currently open.
 * @returns {boolean}
 */
function isMarketOpen() {
    const ist = nowIST();
    const day = ist.getDay(); // 0=Sun, 6=Sat
    if (day === 0 || day === 6) return false;

    const hours = ist.getHours();
    const minutes = ist.getMinutes();
    const timeInMinutes = hours * 60 + minutes;

    const marketOpen = 9 * 60 + 15;   // 09:15
    const marketClose = 15 * 60 + 30;  // 15:30

    return timeInMinutes >= marketOpen && timeInMinutes < marketClose;
}

/**
 * Get the current market mode.
 * @returns {'LIVE' | 'PRE_MARKET' | 'CLOSED'}
 */
function getMarketMode() {
    const ist = nowIST();
    const day = ist.getDay();
    if (day === 0 || day === 6) return 'CLOSED';

    const hours = ist.getHours();
    const minutes = ist.getMinutes();
    const timeInMinutes = hours * 60 + minutes;

    const preMarketOpen = 9 * 60;      // 09:00
    const marketOpen = 9 * 60 + 15;    // 09:15
    const marketClose = 15 * 60 + 30;  // 15:30

    if (timeInMinutes >= marketOpen && timeInMinutes < marketClose) return 'LIVE';
    if (timeInMinutes >= preMarketOpen && timeInMinutes < marketOpen) return 'PRE_MARKET';
    return 'CLOSED';
}

/**
 * Get a full market status object for API responses.
 * @returns {{ mode: string, is_open: boolean, current_time_ist: string, next_open: string|null, message: string }}
 */
function getMarketStatus() {
    const ist = nowIST();
    const mode = getMarketMode();
    const isOpen = mode === 'LIVE';

    // Calculate next market open
    let nextOpen = null;
    if (!isOpen) {
        const next = new Date(ist);
        // If it's before today's open and a weekday, next open is today
        const todayOpenMinutes = 9 * 60 + 15;
        const currentMinutes = ist.getHours() * 60 + ist.getMinutes();
        const day = ist.getDay();

        if (day >= 1 && day <= 5 && currentMinutes < todayOpenMinutes) {
            // Today's open
            next.setHours(9, 15, 0, 0);
        } else {
            // Next business day
            let daysToAdd = 1;
            const nextDay = (day + 1) % 7;
            if (nextDay === 0) daysToAdd = 2; // Sunday → Monday
            if (nextDay === 6) daysToAdd = 2; // Saturday → Monday
            if (day === 0) daysToAdd = 1;     // Sunday → Monday
            next.setDate(next.getDate() + daysToAdd);
            next.setHours(9, 15, 0, 0);
        }
        nextOpen = next.toISOString();
    }

    const messages = {
        'LIVE': 'Market is open. Live data streaming.',
        'PRE_MARKET': 'Pre-market session. Market opens at 09:15 IST.',
        'CLOSED': 'Market closed. Showing last available data.',
    };

    return {
        mode,
        is_open: isOpen,
        current_time_ist: ist.toISOString(),
        next_open: nextOpen,
        message: messages[mode],
    };
}

/**
 * Schedule a callback to run when market opens/closes.
 * @param {'open' | 'close'} event
 * @param {Function} callback
 * @returns {NodeJS.Timer} interval ID for cleanup
 */
function onMarketEvent(event, callback) {
    let lastState = isMarketOpen();
    return setInterval(() => {
        const currentState = isMarketOpen();
        if (event === 'open' && !lastState && currentState) {
            callback();
        }
        if (event === 'close' && lastState && !currentState) {
            callback();
        }
        lastState = currentState;
    }, 30 * 1000); // Check every 30 seconds
}

module.exports = {
    nowIST,
    isMarketOpen,
    getMarketMode,
    getMarketStatus,
    onMarketEvent,
};
