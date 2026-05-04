import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { PostHogProvider } from "@/lib/posthog";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Lio — Voice Assistant for Mac",
  description:
    "A Voice Assistant that lives directly on your Mac, watches your screen and can execute tasks. Anywhere.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${inter.variable} font-inter bg-white text-black antialiased`}>
        <PostHogProvider>{children}</PostHogProvider>
      </body>
    </html>
  );
}
