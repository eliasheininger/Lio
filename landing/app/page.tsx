"use client";

import { useState, useRef } from "react";
import Image from "next/image";
import { motion } from "framer-motion";

// Replace with your actual YouTube video ID
const YOUTUBE_VIDEO_ID = "lfXqRRCTMyA";

export default function Home() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const waitlistRef = useRef<HTMLDivElement>(null);

  function scrollToWaitlist() {
    waitlistRef.current?.scrollIntoView({ behavior: "smooth" });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    const res = await fetch("/api/waitlist", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email }),
    });
    if (res.ok) {
      setStatus("success");
      setEmail("");
    } else {
      setStatus("error");
    }
  }

  return (
    <main className="min-h-screen bg-white flex flex-col items-center px-6">
      {/* Navbar */}
      <nav className="w-full max-w-2xl flex justify-center py-6">
        <Image src="/LioLanding.svg" alt="Lio" width={60} height={24} priority />
      </nav>

      {/* Hero */}
      <section className="w-full max-w-2xl flex flex-col items-center text-center mt-20 gap-5">
        <h1
          className="font-medium leading-snug"
          style={{ fontSize: "28px", letterSpacing: "-0.06em" }}
        >
          A Voice Assistant that lives directly on your Mac, watches your screen
          and can execute tasks.{" "}
          <span className="text-gray-400">Anywhere.</span>
        </h1>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 w-full sm:w-auto justify-center">
          <button
            onClick={scrollToWaitlist}
            className="flex items-center justify-center gap-1.5 px-5 py-2.5 text-base font-medium text-black bg-gray-100 hover:bg-gray-200 transition-colors"
            style={{ borderRadius: "24px" }}
          >
            Watch Demo
            <svg
              width="15"
              height="15"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              className="opacity-60"
            >
              <circle cx="7" cy="7" r="6.5" stroke="currentColor" />
              <path d="M5.5 4.5L9.5 7L5.5 9.5V4.5Z" fill="currentColor" />
            </svg>
          </button>
          <motion.button
            onClick={scrollToWaitlist}
            className="flex items-center justify-center px-5 py-2.5 text-base font-medium text-white"
            style={{ backgroundColor: "#0300CF", borderRadius: "20px" }}
            whileHover={{ scale: 1.04, borderRadius: "18px" }}
            whileTap={{ scale: 0.94, borderRadius: "22px" }}
            transition={{ type: "spring", stiffness: 400, damping: 15 }}
          >
            Sign Up to Waitlist
          </motion.button>
        </div>
      </section>

      {/* Demo Video */}
      <div className="w-full max-w-2xl mt-16 rounded-2xl overflow-hidden shadow-sm border border-gray-100">
        <div className="relative w-full" style={{ aspectRatio: "16/9" }}>
          <iframe
            src={`https://www.youtube.com/embed/${YOUTUBE_VIDEO_ID}`}
            title="Lio Demo"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
            className="absolute inset-0 w-full h-full"
          />
        </div>
      </div>

      {/* Waitlist Section */}
      <section
        ref={waitlistRef}
        className="w-full max-w-sm flex flex-col items-center text-center mt-24 mb-20 gap-8"
      >
        <p
          className="font-medium leading-snug"
          style={{ fontSize: "24px", letterSpacing: "-0.03em" }}
        >
          Be one of the first people to try Lio by signing up to the Waitlist :)
        </p>

        {status === "success" ? (
          <p className="text-base text-gray-500">You&apos;re on the list — we&apos;ll be in touch!</p>
        ) : (
          <form onSubmit={handleSubmit} className="w-full flex flex-col gap-3">
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="your email"
              className="w-full px-4 py-3 bg-gray-100 text-base outline-none transition-colors placeholder:text-gray-400"
              style={{ borderRadius: "20px" }}
            />
            <motion.button
              type="submit"
              disabled={status === "loading"}
              className="w-full py-3 text-white text-base font-medium disabled:opacity-60"
              style={{ backgroundColor: "#0300CF", borderRadius: "20px" }}
              whileHover={{ scale: 1.03, borderRadius: "18px" }}
              whileTap={{ scale: 0.95, borderRadius: "22px" }}
              transition={{ type: "spring", stiffness: 400, damping: 15 }}
            >
              {status === "loading" ? "Sending..." : "Send"}
            </motion.button>
            {status === "error" && (
              <p className="text-sm text-red-500 text-center">Something went wrong — try again.</p>
            )}
          </form>
        )}
      </section>

      {/* Footer */}
      <footer className="pb-10 mt-auto">
        <p className="text-sm text-gray-400">By Elias Heininger</p>
      </footer>
    </main>
  );
}
