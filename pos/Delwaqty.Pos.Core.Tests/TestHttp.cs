using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>Scripted HTTP responses for client tests, capturing requests.</summary>
    internal sealed class StubHandler : HttpMessageHandler
    {
        public readonly List<(HttpMethod Method, string Url, string Body)> Requests =
            new List<(HttpMethod, string, string)>();
        private readonly Queue<(HttpStatusCode Code, string Body)> _responses =
            new Queue<(HttpStatusCode, string)>();

        public StubHandler Respond(HttpStatusCode code, string body)
        {
            _responses.Enqueue((code, body));
            return this;
        }

        public StubHandler Ok(string body) { return Respond(HttpStatusCode.OK, body); }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content == null ? null : await request.Content.ReadAsStringAsync();
            Requests.Add((request.Method, request.RequestUri.ToString(), body));
            if (_responses.Count == 0)
                return new HttpResponseMessage(HttpStatusCode.NotFound) { Content = new StringContent("{}") };
            var (code, text) = _responses.Dequeue();
            return new HttpResponseMessage(code) { Content = new StringContent(text) };
        }
    }
}
