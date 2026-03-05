Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # ✅ Dev + Prod
    origins "http://localhost:5173",
            "http://127.0.0.1:5173",
            "https://YOUR-VERCEL-DOMAIN.vercel.app"

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end