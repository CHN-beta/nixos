import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "问答箱 | MiniBox",
  description: "匿名问答箱",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
