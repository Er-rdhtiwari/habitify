import { useEffect, useMemo, useState } from "react";

const defaultConfig = { apiBaseUrl: "" };

export default function Home() {
  const [config, setConfig] = useState(defaultConfig);
  const [reminders, setReminders] = useState([]);
  const [habits, setHabits] = useState([]);
  const [reminderForm, setReminderForm] = useState({ title: "", dueDate: "" });
  const [habitForm, setHabitForm] = useState({ name: "" });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const apiBase = useMemo(() => {
    const base = config?.apiBaseUrl || "";
    return base.endsWith("/") ? base.slice(0, -1) : base;
  }, [config]);

  useEffect(() => {
    if (typeof window !== "undefined") {
      setConfig(window.__APP_CONFIG || defaultConfig);
    }
  }, []);

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const [reminderData, habitData] = await Promise.all([
          fetchJson(apiBase, "/api/reminders"),
          fetchJson(apiBase, "/api/habits"),
        ]);
        setReminders(reminderData);
        setHabits(habitData);
      } catch (err) {
        setError(err.message || "Failed to load data");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [apiBase]);

  const fetchJson = async (base, path, options = {}) => {
    const res = await fetch(`${base}${path}`, {
      headers: {
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
      ...options,
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data?.error || "Request failed");
    }
    return data;
  };

  const handleAddReminder = async () => {
    if (!reminderForm.title.trim()) return;
    try {
      const payload = {
        title: reminderForm.title.trim(),
        dueDate: reminderForm.dueDate,
      };
      const saved = await fetchJson(apiBase, "/api/reminders", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      setReminders((prev) => [...prev, saved]);
      setReminderForm({ title: "", dueDate: "" });
      setError("");
    } catch (err) {
      setError(err.message);
    }
  };

  const toggleReminder = async (reminder) => {
    try {
      const saved = await fetchJson(apiBase, "/api/reminders", {
        method: "POST",
        body: JSON.stringify({
          id: reminder.id,
          completed: !reminder.completed,
        }),
      });
      setReminders((prev) =>
        prev.map((r) => (r.id === reminder.id ? saved : r))
      );
      setError("");
    } catch (err) {
      setError(err.message);
    }
  };

  const handleAddHabit = async () => {
    if (!habitForm.name.trim()) return;
    try {
      const payload = { name: habitForm.name.trim() };
      const saved = await fetchJson(apiBase, "/api/habits", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      setHabits((prev) => [...prev, saved]);
      setHabitForm({ name: "" });
      setError("");
    } catch (err) {
      setError(err.message);
    }
  };

  const checkHabit = async (habit) => {
    try {
      const updated = await fetchJson(
        apiBase,
        `/api/habits/${habit.id}/check`,
        { method: "POST" }
      );
      setHabits((prev) =>
        prev.map((h) => (h.id === habit.id ? updated : h))
      );
      setError("");
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="page">
      <div className="hero">
        <div>
          <div className="badge">
            <span>Personal Reminder + Habit Tracker</span>
          </div>
          <h1 style={{ margin: "12px 0 4px" }}>Stay on track effortlessly.</h1>
          <p className="muted" style={{ margin: 0 }}>
            Add reminders, check in on habits, and see progress in one place.
          </p>
        </div>
        <div className="status">
          <span
            style={{
              display: "inline-block",
              width: 8,
              height: 8,
              borderRadius: "50%",
              background: error ? "#f39c12" : "#3ec2f3",
            }}
          ></span>
          {error ? "Check connection" : "Live"}
        </div>
      </div>

      <div className="card-grid">
        <div className="card">
          <h3>Reminders</h3>
          <div className="input-row">
            <input
              placeholder="Buy groceries, call Alex..."
              value={reminderForm.title}
              onChange={(e) =>
                setReminderForm((prev) => ({ ...prev, title: e.target.value }))
              }
            />
            <input
              type="date"
              value={reminderForm.dueDate}
              onChange={(e) =>
                setReminderForm((prev) => ({
                  ...prev,
                  dueDate: e.target.value,
                }))
              }
            />
            <button className="button" onClick={handleAddReminder}>
              Add
            </button>
          </div>
          {loading ? (
            <div className="muted">Loading reminders...</div>
          ) : reminders.length === 0 ? (
            <div className="empty">No reminders yet.</div>
          ) : (
            <div className="list">
              {reminders.map((reminder) => (
                <div className="item" key={reminder.id}>
                  <div className="meta">
                    <strong>{reminder.title}</strong>
                    <div className="muted">
                      {reminder.dueDate
                        ? `Due ${reminder.dueDate}`
                        : "No due date"}
                    </div>
                  </div>
                  <button
                    className="button secondary"
                    onClick={() => toggleReminder(reminder)}
                  >
                    {reminder.completed ? "Completed" : "Mark done"}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="card">
          <h3>Habits</h3>
          <div className="input-row">
            <input
              placeholder="Drink water, meditate..."
              value={habitForm.name}
              onChange={(e) =>
                setHabitForm((prev) => ({ ...prev, name: e.target.value }))
              }
            />
            <button className="button" onClick={handleAddHabit}>
              Add
            </button>
          </div>
          {loading ? (
            <div className="muted">Loading habits...</div>
          ) : habits.length === 0 ? (
            <div className="empty">No habits yet.</div>
          ) : (
            <div className="list">
              {habits.map((habit) => (
                <div className="item" key={habit.id}>
                  <div className="meta">
                    <strong>{habit.name}</strong>
                    <div className="muted">
                      Streak: {habit.streak} day{habit.streak === 1 ? "" : "s"}
                    </div>
                    {habit.lastCheck && (
                      <span className="pill">
                        Last check-in: {new Date(habit.lastCheck).toLocaleString()}
                      </span>
                    )}
                  </div>
                  <button
                    className="button secondary"
                    onClick={() => checkHabit(habit)}
                  >
                    Check in
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {error && (
        <div
          style={{
            marginTop: 16,
            padding: "12px 14px",
            borderRadius: 12,
            border: "1px solid rgba(255,255,255,0.12)",
            background: "rgba(255, 255, 255, 0.06)",
            color: "#f39c12",
          }}
        >
          {error}
        </div>
      )}
    </div>
  );
}
