import { Provider } from "./Provider";
import { Home } from "./pages/Home";
import { OAuthCallback } from "./pages/OAuthCallback";

function Router() {
  if (window.location.pathname === "/oauth/callback") {
    return <OAuthCallback />;
  }
  return <Home />;
}

export function App() {
  return (
    <Provider>
      <Router />
    </Provider>
  );
}

